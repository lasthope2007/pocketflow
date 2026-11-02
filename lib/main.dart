import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

const mint = Color(0xFF70E0B4);
const ink = Color(0xFF142B32);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.database;
  runApp(const PocketFlowApp());
}

class PocketFlowApp extends StatelessWidget {
  const PocketFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: mint, brightness: Brightness.dark);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PocketFlow',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF101B20),
        cardTheme: CardThemeData(
          color: const Color(0xFF19282E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      home: const Directionality(textDirection: TextDirection.rtl, child: HomePage()),
    );
  }
}

class Store {
  Store._();
  static final instance = Store._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final folder = await getDatabasesPath();
    _db = await openDatabase(
      path.join(folder, 'pocketflow.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, percent INTEGER NOT NULL, allocated INTEGER NOT NULL DEFAULT 0, spent INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, category_id INTEGER, amount INTEGER NOT NULL, title TEXT NOT NULL, created_at TEXT NOT NULL)');
        final batch = db.batch();
        final defaults = [['خوراک',20],['تفریح',10],['آموزش',15],['پس‌انداز',25],['شخصی',30]];
        for (final item in defaults) {
          batch.insert('categories', {'name':item[0],'percent':item[1],'allocated':0,'spent':0});
        }
        await batch.commit(noResult: true);
      },
    );
    return _db!;
  }

  Future<List<Map<String,Object?>>> categories() async => (await database).query('categories', orderBy:'id');
  Future<List<Map<String,Object?>>> activity() async => (await database).query('transactions', orderBy:'created_at DESC', limit:6);

  Future<int> total(String type) async {
    final rows = await (await database).rawQuery('SELECT COALESCE(SUM(amount),0) AS value FROM transactions WHERE type = ?', [type]);
    return (rows.first['value'] as int?) ?? 0;
  }

  Future<void> income(int amount, String title) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('categories');
      final percentTotal = rows.fold<int>(0,(sum,row) => sum + (row['percent'] as int));
      if (percentTotal > 100) throw StateError('مجموع درصدها نباید بیشتر از ۱۰۰ باشد.');
      await txn.insert('transactions', {'type':'income','amount':amount,'title':title,'created_at':DateTime.now().toIso8601String()});
      for (final row in rows) {
        final share = amount * (row['percent'] as int) ~/ 100;
        if (share > 0) {
          await txn.rawUpdate('UPDATE categories SET allocated = allocated + ? WHERE id = ?', [share,row['id']]);
        }
      }
    });
  }

  Future<void> expense(int categoryId, int amount, String title) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {'type':'expense','category_id':categoryId,'amount':amount,'title':title,'created_at':DateTime.now().toIso8601String()});
      await txn.rawUpdate('UPDATE categories SET spent = spent + ? WHERE id = ?', [amount,categoryId]);
    });
  }
}

String fmt(int value) => NumberFormat('#,###','en_US').format(value);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int incomeTotal = 0;
  int expenseTotal = 0;
  int tab = 0;
  bool loading = true;
  List<Map<String,Object?>> categories = [];
  List<Map<String,Object?>> activity = [];

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    final store = Store.instance;
    final values = await Future.wait([store.total('income'),store.total('expense'),store.categories(),store.activity()]);
    if (!mounted) return;
    setState(() {
      incomeTotal = values[0] as int;
      expenseTotal = values[1] as int;
      categories = values[2] as List<Map<String,Object?>>;
      activity = values[3] as List<Map<String,Object?>>;
      loading = false;
    });
  }

  void message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> addIncome() async {
    final amount = TextEditingController();
    final title = TextEditingController(text:'درآمد روزانه');
    final ok = await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('ثبت درآمد'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ به تومان')),
        const SizedBox(height:12),
        TextField(controller:title,decoration:const InputDecoration(labelText:'منبع درآمد')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('انصراف')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ثبت و تقسیم')),
      ],
    ));
    if (ok != true) return;
    final value = int.tryParse(amount.text.replaceAll(',','').trim());
    if (value == null || value <= 0) { message('مبلغ معتبر وارد کن.'); return; }
    try {
      await Store.instance.income(value,title.text.trim());
      await refresh();
      message('درآمد ثبت و طبق درصدها تقسیم شد.');
    } catch (error) { message(error.toString()); }
  }

  Future<void> addExpense(Map<String,Object?> category) async {
    final amount = TextEditingController();
    final title = TextEditingController();
    final allocated = category['allocated'] as int;
    final spent = category['spent'] as int;
    final remaining = allocated - spent;
    final ok = await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:Text('هزینه '+(category['name'] as String)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('مانده فعلی: '+fmt(remaining)+' تومان'),
        const SizedBox(height:12),
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مبلغ هزینه')),
        const SizedBox(height:12),
        TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان هزینه')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('انصراف')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ادامه')),
      ],
    ));
    if (ok != true) return;
    final value = int.tryParse(amount.text.replaceAll(',','').trim());
    if (value == null || value <= 0) { message('مبلغ معتبر وارد کن.'); return; }
    if (value > remaining) {
      final confirm = await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
        title:const Text('هزینه بیشتر از بودجه'),
        content:Text('این هزینه '+fmt(value-remaining)+' تومان بیشتر از مانده است. ثبت شود؟'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('بازگشت')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('ثبت با تأیید')),
        ],
      ));
      if (confirm != true) return;
    }
    await Store.instance.expense(category['id'] as int,value,title.text.trim().isEmpty?'هزینه':title.text.trim());
    await refresh();
    message('هزینه ثبت شد.');
  }

  @override
  Widget build(BuildContext context) {
    final balance = incomeTotal - expenseTotal;
    return Scaffold(
      appBar:AppBar(title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('PocketFlow',style:TextStyle(fontWeight:FontWeight.w900)),
        Text('مدیریت مالی شخصی',style:TextStyle(fontSize:11,color:Colors.white54)),
      ])),
      body:loading ? const Center(child:CircularProgressIndicator()) : tab == 0 ? RefreshIndicator(onRefresh:refresh,child:dashboard(balance)) : placeholder(),
      floatingActionButton:tab == 0 ? FloatingActionButton.extended(
        onPressed:addIncome,backgroundColor:mint,foregroundColor:ink,
        icon:const Icon(Icons.add_rounded),label:const Text('ثبت درآمد',style:TextStyle(fontWeight:FontWeight.bold)),
      ) : null,
      bottomNavigationBar:NavigationBar(
        selectedIndex:tab,
        onDestinationSelected:(value)=>setState(()=>tab=value),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.space_dashboard_outlined),label:'خانه'),
          NavigationDestination(icon:Icon(Icons.wallet_outlined),label:'بودجه‌ها'),
          NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'تراکنش‌ها'),
          NavigationDestination(icon:Icon(Icons.insights_outlined),label:'گزارش‌ها'),
        ],
      ),
    );
  }

  Widget dashboard(int balance) => ListView(
    physics:const AlwaysScrollableScrollPhysics(),
    padding:const EdgeInsets.fromLTRB(16,8,16,110),
    children:[
      Container(
        padding:const EdgeInsets.all(22),
        decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(26),
          gradient:const LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[Color(0xFF28534B),Color(0xFF172F36),ink]),
          border:Border.all(color:mint.withValues(alpha:.2)),
        ),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('موجودی خالص ثبت‌شده',style:TextStyle(color:Colors.white70)),
          const SizedBox(height:10),
          FittedBox(fit:BoxFit.scaleDown,child:Text(fmt(balance)+' تومان',style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900))),
          const SizedBox(height:14),
          const Row(children:[Icon(Icons.offline_bolt_rounded,color:mint,size:17),SizedBox(width:6),Text('اطلاعات روی همین دستگاه ذخیره می‌شود',style:TextStyle(fontSize:11,color:Colors.white70))]),
        ]),
      ),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:summary('درآمد',incomeTotal,Icons.south_west_rounded,mint)),
        const SizedBox(width:12),
        Expanded(child:summary('هزینه',expenseTotal,Icons.north_east_rounded,const Color(0xFFFF9999))),
      ]),
      const SizedBox(height:24),
      const Text('بودجه‌های من',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      ...categories.map(categoryCard),
      const SizedBox(height:16),
      const Text('آخرین فعالیت‌ها',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      if (activity.isEmpty)
        const Card(child:Padding(padding:EdgeInsets.all(22),child:Column(children:[
          Icon(Icons.auto_awesome_rounded,color:mint,size:30),
          SizedBox(height:10),
          Text('شروع ساده است',style:TextStyle(fontWeight:FontWeight.bold)),
          SizedBox(height:4),
          Text('اولین درآمدت را ثبت کن تا بودجه‌ها شکل بگیرند.',textAlign:TextAlign.center),
        ])))
      else ...activity.map((item){
        final isIncome = item['type']=='income';
        return ListTile(
          leading:CircleAvatar(backgroundColor:(isIncome?mint:Colors.redAccent).withValues(alpha:.13),child:Icon(isIncome?Icons.south_west:Icons.north_east,color:isIncome?mint:Colors.redAccent)),
          title:Text(item['title'] as String),
          subtitle:Text(DateFormat('yyyy/MM/dd').format(DateTime.parse(item['created_at'] as String))),
          trailing:Text((isIncome?'+':'−')+fmt(item['amount'] as int),style:TextStyle(fontWeight:FontWeight.bold,color:isIncome?mint:Colors.redAccent)),
        );
      }),
    ],
  );

  Widget summary(String title,int amount,IconData icon,Color color)=>Card(
    child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:color),const SizedBox(height:12),
      Text(title,style:const TextStyle(color:Colors.white60,fontSize:12)),
      const SizedBox(height:5),
      FittedBox(child:Text(fmt(amount),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))),
      const Text('تومان',style:TextStyle(color:Colors.white54,fontSize:10)),
    ])),
  );

  Widget categoryCard(Map<String,Object?> item) {
    final allocated = item['allocated'] as int;
    final spent = item['spent'] as int;
    final remaining = allocated-spent;
    final progress = allocated<=0?0.0:(spent/allocated).clamp(0.0,1.0);
    return Card(
      margin:const EdgeInsets.only(bottom:10),
      child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
        Row(children:[
          const CircleAvatar(backgroundColor:Color(0x2270E0B4),child:Icon(Icons.wallet_rounded,color:mint)),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(item['name'] as String,style:const TextStyle(fontWeight:FontWeight.w800)),
            Text((item['percent'].toString())+'٪ از درآمدهای جدید',style:const TextStyle(color:Colors.white54,fontSize:11)),
          ])),
          Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
            Text(fmt(remaining),style:TextStyle(color:remaining<0?Colors.redAccent:mint,fontWeight:FontWeight.w900)),
            const Text('مانده · تومان',style:TextStyle(color:Colors.white54,fontSize:10)),
          ]),
        ]),
        const SizedBox(height:13),
        ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(value:progress,minHeight:7,backgroundColor:Colors.white10,color:mint)),
        const SizedBox(height:7),
        Row(children:[
          Text('خرج‌شده: '+fmt(spent),style:const TextStyle(color:Colors.white54,fontSize:10)),
          const Spacer(),
          Text('بودجه: '+fmt(allocated),style:const TextStyle(color:Colors.white54,fontSize:10)),
          IconButton(tooltip:'ثبت هزینه',visualDensity:VisualDensity.compact,onPressed:()=>addExpense(item),icon:const Icon(Icons.remove_circle_outline,color:Color(0xFFFF9999))),
        ]),
      ])),
    );
  }

  Widget placeholder() {
    final title = tab==1?'مدیریت بودجه‌ها':tab==2?'تاریخچه تراکنش‌ها':'گزارش‌های مالی';
    return Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.construction_rounded,color:mint,size:38),
      const SizedBox(height:14),
      Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      const Text('این بخش در حال ساخت است. زیرساخت دیتابیس و داشبورد اولیه آماده شده است.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white60)),
    ])));
  }
}
