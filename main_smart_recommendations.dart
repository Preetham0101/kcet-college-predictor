import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const cats=['1G','1K','1R','2AG','2AK','2AR','2BG','2BK','2BR','3AG','3AK','3AR','3BG','3BK','3BR','GM','GMK','GMP','GMR','NRI','OPN','OTH','S1G','S1K','S1R','S2G','S2K','S2R','S3G','S3K','S3R','S4G','S4K','S4R','STG','STK','STR'];
void main()=>runApp(const KcetApp());
class KcetApp extends StatelessWidget { const KcetApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(title:'KCET College Predictor',debugShowCheckedModeBanner:false,theme:ThemeData(
 colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff3157c8),brightness:Brightness.light),
 useMaterial3:true,
 scaffoldBackgroundColor:const Color(0xfff5f7fc),
 appBarTheme:const AppBarTheme(centerTitle:false,elevation:0,backgroundColor:Color(0xfff5f7fc),surfaceTintColor:Colors.transparent),
 cardTheme:CardThemeData(color:Colors.white,elevation:0,margin:const EdgeInsets.only(bottom:12),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:const BorderSide(color:Color(0xffe7eaf2)))),
 inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:const Color(0xfff8f9fd),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:Color(0xffe0e4ee))),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14)),
),home:const Predictor());}

Widget _metric(BuildContext context,String label,String value) => Column(
  crossAxisAlignment:CrossAxisAlignment.start,
  mainAxisSize:MainAxisSize.min,
  children:[
    Text(label,style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height:3),
    Text(value,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800)),
  ],
);


class CollegeDetailsPage extends StatelessWidget {
  const CollegeDetailsPage({
    super.key,
    required this.college,
    required this.studentRank,
    required this.isSaved,
    required this.onToggleSaved,
  });

  final Map<String, dynamic> college;
  final int studentRank;
  final bool isSaved;
  final VoidCallback onToggleSaved;

  Widget _detail(BuildContext context, String label, String value) {
    if (value.trim().isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(flex: 6, child: Text(value, textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = '${college['status'] ?? ''}';
    final within = status == 'Historically within cutoff';
    final cutoff = college['cutoff_rank'];
    final rawDifference = college['rank_difference'];
    final difference = rawDifference is num
        ? rawDifference.toInt()
        : int.tryParse('$rawDifference') ?? 0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('College details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${college['college'] ?? 'College name unavailable'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${college['branch'] ?? 'Branch not provided'}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Chip(
                avatar: Icon(within ? Icons.check_circle : Icons.info_outline,
                  color: within ? const Color(0xff18794e) : const Color(0xffa15c08)),
                label: Text(within ? 'Within historical cutoff' : 'Outside historical cutoff'),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 20, runSpacing: 12, children: [
                _metric(context, 'Closing rank', '$cutoff'),
                _metric(context, 'Your rank', '$studentRank'),
                _metric(context, 'Rank difference', '${difference.abs()}'),
              ]),
              const SizedBox(height: 10),
              Text(
                difference >= 0
                    ? 'Your rank is $difference positions better than or equal to the historical closing rank.'
                    : 'Your rank is ${difference.abs()} positions beyond the historical closing rank.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ]),
          )),
          Card(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('College and cutoff information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Divider(height: 18),
              _detail(context, 'College code', '${college['college_code'] ?? ''}'),
              _detail(context, 'Branch', '${college['branch'] ?? ''}'),
              _detail(context, 'District / location', '${college['district'] ?? college['location'] ?? ''}'),
              _detail(context, 'Category', '${college['category'] ?? ''}'),
              _detail(context, 'Quota', '${college['quota'] ?? ''}'),
              _detail(context, 'Counselling round', '${college['round'] ?? ''}'),
              _detail(context, 'Cutoff year', '${college['year'] ?? ''}'),
              _detail(context, 'Historical closing rank', '$cutoff'),
              _detail(context, 'Result group', '${college['match_group'] ?? ''}'),
            ]),
          )),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Important note',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'This comparison uses historical cutoff data from the uploaded file. '
                'It is not an admission guarantee. Confirm college details and the latest '
                'official KEA cutoffs before making a choice.',
                style: TextStyle(height: 1.45),
              ),
            ]),
          )),
          FilledButton.icon(
            onPressed: () {
              onToggleSaved();
              Navigator.pop(context);
            },
            icon: Icon(isSaved ? Icons.bookmark_remove : Icons.bookmark_add),
            label: Text(isSaved ? 'Remove from shortlist' : 'Save to shortlist'),
          ),
        ],
      ),
    );
  }
}


class ShortlistComparePage extends StatefulWidget {
  const ShortlistComparePage({super.key, required this.colleges});
  final List<Map<String, dynamic>> colleges;

  @override
  State<ShortlistComparePage> createState() => _ShortlistComparePageState();
}

class _ShortlistComparePageState extends State<ShortlistComparePage> {
  final Set<int> selected = {};

  String value(Map<String, dynamic> college, String key) {
    final result = college[key];
    return result == null || '$result'.trim().isEmpty ? '—' : '$result';
  }

  @override
  Widget build(BuildContext context) {
    final chosen = selected.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Compare colleges')),
      body: widget.colleges.isEmpty
          ? const Center(child: Text('Your shortlist is empty. Save colleges first.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Select at least two colleges to compare.',
                  style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                ...List.generate(widget.colleges.length, (index) {
                  final college = widget.colleges[index];
                  return Card(
                    child: CheckboxListTile(
                      value: selected.contains(index),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          if (selected.length < 3) {
                            selected.add(index);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Compare up to 3 colleges at a time.')),
                            );
                          }
                        } else {
                          selected.remove(index);
                        }
                      }),
                      title: Text(value(college, 'college'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${value(college, 'branch')} · ${value(college, 'district') == '—' ? value(college, 'location') : value(college, 'district')}'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: selected.length < 2
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CollegeComparisonTable(
                            colleges: chosen.map((i) => widget.colleges[i]).toList(),
                          ),
                        )),
                  icon: const Icon(Icons.compare_arrows),
                  label: Text('Compare selected (${selected.length}/3)'),
                ),
              ],
            ),
    );
  }
}

class CollegeComparisonTable extends StatelessWidget {
  const CollegeComparisonTable({super.key, required this.colleges});
  final List<Map<String, dynamic>> colleges;

  String display(dynamic value) =>
      value == null || '$value'.trim().isEmpty ? '—' : '$value';

  int? closingRank(Map<String, dynamic> college) {
    final raw = college['cutoff_rank'];
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  @override
  Widget build(BuildContext context) {
    final ranks = colleges.map(closingRank).whereType<int>().toList();
    final bestRank = ranks.isEmpty ? null : ranks.reduce((a, b) => a < b ? a : b);
    final fields = <(String, String, IconData)>[
      ('College code', 'college_code', Icons.tag),
      ('Branch', 'branch', Icons.account_tree_outlined),
      ('District', 'district', Icons.location_city_outlined),
      ('Location', 'location', Icons.place_outlined),
      ('Category', 'category', Icons.category_outlined),
      ('Rank difference', 'rank_difference', Icons.compare_arrows),
      ('Cutoff year', 'year', Icons.calendar_today_outlined),
      ('Quota', 'quota', Icons.groups_outlined),
      ('Round', 'round', Icons.flag_outlined),
      ('Historical status', 'status', Icons.info_outline),
    ];

    Widget detailRow(IconData icon, String label, dynamic value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 9),
          SizedBox(width: 104, child: Text(label,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(width: 8),
          Expanded(child: Text(display(value),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('College comparison')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Compare ${colleges.length} shortlisted colleges',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Swipe sideways to view each college. Historical cutoff ranks are reference values only.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            height: 530,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colleges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final college = colleges[index];
                final rank = closingRank(college);
                final isLowest = rank != null && rank == bestRank;
                return SizedBox(
                  width: 285,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        color: isLowest ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (isLowest)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.emoji_events_outlined, size: 16, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                const SizedBox(width: 5),
                                Text('LOWEST CLOSING RANK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ]),
                            ),
                          Text(display(college['college']), maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Text('HISTORICAL CLOSING RANK', style: TextStyle(fontSize: 10, letterSpacing: .5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(rank?.toString() ?? '—', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: isLowest ? Theme.of(context).colorScheme.primary : null)),
                        ]),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          children: [
                            ...fields.map((field) => detailRow(field.$3, field.$1, college[field.$2])),
                          ],
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 19),
                const SizedBox(width: 9),
                Expanded(child: Text(
                  'The highlighted college has the lowest numeric closing rank among the selected records. This does not mean it is the best college overall or guarantee admission. Verify current official KEA cutoffs, course details and seat availability.',
                  style: TextStyle(fontSize: 12, height: 1.45, color: Theme.of(context).colorScheme.onSurfaceVariant),
                )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class Predictor extends StatefulWidget {const Predictor({super.key});@override State<Predictor> createState()=>_PredictorState();}
class _PredictorState extends State<Predictor>{
 String? token, accountEmail; bool authBusy=false; String authMode='login'; final email=TextEditingController(), password=TextEditingController(); List<Map<String,dynamic>> saved=[]; String? cloudMessage;
 @override void initState(){super.initState();_loadSession();}
 Future<void> _loadSession() async {final p=await SharedPreferences.getInstance(); final t=p.getString('kcet_token'); final e=p.getString('kcet_email'); final raw=p.getString('kcet_saved')??'[]'; try{final list=jsonDecode(raw) as List; saved=list.map((x)=>Map<String,dynamic>.from(x as Map)).toList();}catch(_){} if(t!=null){token=t;accountEmail=e;try{final r=await http.get(Uri.parse('$api/me/shortlist'),headers:{'Authorization':'Bearer $t'});if(r.statusCode==200){final body=jsonDecode(r.body);saved=(body['colleges'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();await _saveLocal();}else{token=null;}}catch(_){cloudMessage='Cloud unavailable; local shortlist retained.';}} if(mounted)setState((){});}
 Future<void> _saveLocal() async {final p=await SharedPreferences.getInstance();await p.setString('kcet_saved',jsonEncode(saved));if(token!=null){try{final r=await http.put(Uri.parse('$api/me/shortlist'),headers:{'Authorization':'Bearer $token','Content-Type':'application/json'},body:jsonEncode({'colleges':saved}));cloudMessage=r.statusCode==200?'Cloud shortlist synced.':'Cloud sync failed.';}catch(_){cloudMessage='Cloud sync failed; saved locally.';}}}
 Future<void> _auth() async {if(email.text.trim().isEmpty||password.text.length<8){setState(()=>cloudMessage='Enter an email and password of at least 8 characters.');return;}setState(()=>authBusy=true);try{final r=await http.post(Uri.parse('$api/auth/${authMode=='register'?'register':'login'}'),headers:{'Content-Type':'application/json'},body:jsonEncode({'email':email.text.trim(),'password':password.text}));final j=jsonDecode(r.body);if(r.statusCode<200||r.statusCode>=300)throw Exception(j['detail']??'Account request failed');token=j['access_token'];accountEmail=j['email'];final p=await SharedPreferences.getInstance();await p.setString('kcet_token',token!);await p.setString('kcet_email',accountEmail!);final sr=await http.get(Uri.parse('$api/me/shortlist'),headers:{'Authorization':'Bearer $token'});if(sr.statusCode==200){saved=(jsonDecode(sr.body)['colleges'] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();await _saveLocal();}setState(()=>cloudMessage='Signed in. Your shortlist is synced.');}catch(e){setState(()=>cloudMessage=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>authBusy=false);}}
 Future<void> _toggleSaved(Map<String,dynamic> row) async {final key='${row['college_code']??row['college']}|${row['branch']}|${row['category']}|${row['cutoff_rank']}|${row['year']}|${row['round']}|${row['quota']}';final exists=saved.any((x)=>'${x['college_code']??x['college']}|${x['branch']}|${x['category']}|${x['cutoff_rank']}|${x['year']}|${x['round']}|${x['quota']}'==key);setState(()=>exists?saved.removeWhere((x)=>'${x['college_code']??x['college']}|${x['branch']}|${x['category']}|${x['cutoff_rank']}|${x['year']}|${x['round']}|${x['quota']}'==key):saved.add(row));await _saveLocal();}

 final rank=TextEditingController(text:'35000'), branch=TextEditingController(), district=TextEditingController(), round=TextEditingController();
 String cat='3AG'; PlatformFile? file; bool busy=false; String? error; Map<String,dynamic>? data;
 final searchController=TextEditingController();
 String sortBy='Recommended order';
 String resultFilter='All results';
 final api=const String.fromEnvironment('KCET_API_URL',defaultValue:'http://10.0.2.2:8000');
 Future<void> pick()async{final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['csv','xlsx','xls','pdf'],withData:true);if(r!=null&&r.files.isNotEmpty)setState(()=>file=r.files.single);}
 Future<void> runPrediction()async{
  final n=int.tryParse(rank.text.trim());if(n==null||n<1){setState(()=>error='Enter a valid rank.');return;}if(file==null){setState(()=>error='Choose a cutoff file first.');return;}
  setState(() { busy = true; error = null; data = null; });
  try{final req=http.MultipartRequest('POST',Uri.parse('$api/predict'));req.fields.addAll({'rank':'$n','category':cat,'branch':branch.text.trim(),'location':district.text.trim(),'round_name':round.text.trim()});
   final f=file!;if(f.bytes!=null){req.files.add(http.MultipartFile.fromBytes('file',f.bytes!,filename:f.name));}else if(f.path!=null){req.files.add(await http.MultipartFile.fromPath('file',f.path!,filename:f.name));}else{throw Exception('Cannot read file; choose it again.');}
   final res=await req.send().timeout(const Duration(minutes:5));final body=await res.stream.bytesToString();final json=jsonDecode(body);
   if(res.statusCode<200||res.statusCode>=300)throw Exception(json is Map?json['detail']??'Prediction failed':'Prediction failed');
   setState(()=>data=Map<String,dynamic>.from(json as Map));
  }catch(e){setState(()=>error='API request failed: $e');}finally{setState(()=>busy=false);}
 }
 @override void dispose(){rank.dispose();branch.dispose();district.dispose();round.dispose();email.dispose();password.dispose();searchController.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  final sourceRows=data?['results'] as List? ?? const [];
  final query=searchController.text.trim().toLowerCase();
  final rows=sourceRows.where((value){
   final x=Map<String,dynamic>.from(value as Map);
   final status='${x['status'] ?? ''}';
   final group='${x['match_group'] ?? 'Karnataka'}';
   final searchable=[x['college'],x['college_code'],x['branch'],x['location'],x['category'],x['district'],x['quota'],x['round'],x['year']]
    .where((v)=>v!=null).join(' ').toLowerCase();
   final matchesQuery=query.isEmpty || searchable.contains(query);
   final matchesFilter=switch(resultFilter){
    'Within historical cutoff'=>status=='Historically within cutoff',
    'Outside historical cutoff'=>status!='Historically within cutoff',
    'Selected district'=>group=='Selected district',
    'Other Karnataka districts'=>group=='Other Karnataka districts',
    'District unverified'=>group=='Karnataka fallback — district unverified',
    _=>true,
   };
   return matchesQuery && matchesFilter;
  }).toList();
  int rankOf(dynamic value){final raw=(value as Map)['cutoff_rank'];return raw is num?raw.toInt():int.tryParse('$raw')??0;}
  int smartScore(dynamic value){
   final x=Map<String,dynamic>.from(value as Map);
   final status='${x['status'] ?? ''}';
   final group='${x['match_group'] ?? ''}';
   final rawMargin=x['rank_difference'];
   final margin=rawMargin is num?rawMargin.toInt():int.tryParse('$rawMargin')??0;
   final studentRank=int.tryParse(rank.text.trim())??1;
   var score=status=='Historically within cutoff'?50:0;
   if(group=='Selected district') score+=20;
   else if(group=='Other Karnataka districts') score+=10;
   if(margin>0) score+=(30*margin/studentRank).round().clamp(0,30).toInt();
   return score.clamp(0,100).toInt();
  }
  rows.sort((a,b){
   final x=Map<String,dynamic>.from(a as Map); final y=Map<String,dynamic>.from(b as Map);
   switch(sortBy){
    case 'Smart match (recommended)': return smartScore(b).compareTo(smartScore(a));
    case 'Closing rank: low to high': return rankOf(a).compareTo(rankOf(b));
    case 'Closing rank: high to low': return rankOf(b).compareTo(rankOf(a));
    case 'College name: A–Z': return '${x['college']??''}'.toLowerCase().compareTo('${y['college']??''}'.toLowerCase());
    default: return 0;
   }
  });
  return Scaffold(appBar:AppBar(title:const Text('KCET College Predictor'),actions:[
 IconButton(
  tooltip:'Compare shortlisted colleges',
  onPressed:()=>Navigator.push(context,MaterialPageRoute(
    builder:(_)=>ShortlistComparePage(colleges:saved.map((x)=>Map<String,dynamic>.from(x)).toList()),
  )),
  icon:const Icon(Icons.compare_arrows),
 ),
 IconButton(tooltip:'My shortlist',onPressed:()=>showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[Text('My Shortlist (${saved.length})',style:Theme.of(context).textTheme.titleLarge),...saved.map((x)=>ListTile(title:Text('${x['college']??'College'}'),subtitle:Text('${x['branch']??''} · Closing rank ${x['cutoff_rank']??'—'}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:(){_toggleSaved(x);Navigator.pop(ctx);}))) ]))),icon:const Icon(Icons.bookmarks_outlined))]),body:ListView(padding:const EdgeInsets.all(16),children:[
   Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(token==null?'Optional account · Sync shortlist across devices':'Signed in: ${accountEmail??''}',style:const TextStyle(fontWeight:FontWeight.bold)),if(token==null)...[TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),const SizedBox(height:8),TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password (8+ characters)',border:OutlineInputBorder())),const SizedBox(height:8),Row(children:[Expanded(child:FilledButton(onPressed:authBusy?null:_auth,child:Text(authBusy?'Please wait…':authMode=='register'?'Create account':'Sign in'))),TextButton(onPressed:()=>setState(()=>authMode=authMode=='login'?'register':'login'),child:Text(authMode=='login'?'Register':'Sign in'))])]else TextButton(onPressed:()async{final p=await SharedPreferences.getInstance();await p.remove('kcet_token');await p.remove('kcet_email');setState(() { token = null; accountEmail = null; cloudMessage = 'Signed out. Local shortlist remains.'; });},child:const Text('Sign out')),if(cloudMessage!=null)Text(cloudMessage!,style:const TextStyle(fontSize:12))]))),
   const Text('Find colleges that fit your rank',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800,letterSpacing:-.5)),const SizedBox(height:8),
   Text('Compare your KCET rank with official historical cutoff data from the file you upload.',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,height:1.45)),const SizedBox(height:18),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    TextField(controller:rank,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'KCET rank',border:OutlineInputBorder())),
    const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:cat,decoration:const InputDecoration(labelText:'Category',border:OutlineInputBorder()),items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x){if(x!=null)setState(()=>cat=x);}),
    const SizedBox(height:12),TextField(controller:branch,decoration:const InputDecoration(labelText:'Branch filter (optional)',hintText:'Computer Science',border:OutlineInputBorder())),
    const SizedBox(height:12),TextField(controller:district,decoration:const InputDecoration(labelText:'District / location (optional)',hintText:'Bengaluru Urban, Mysuru, Ramanagara',border:OutlineInputBorder())),
    const SizedBox(height:12),TextField(controller:round,decoration:const InputDecoration(labelText:'Counselling round (optional)',border:OutlineInputBorder())),
    const SizedBox(height:12),OutlinedButton.icon(onPressed:busy?null:pick,icon:const Icon(Icons.upload_file),label:Text(file?.name??'Choose cutoff file')),
    const SizedBox(height:12),FilledButton.icon(
      onPressed:busy?null:runPrediction,
      icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.auto_awesome),
      label:Text(busy?'Analyzing cutoff data…':'Find matching colleges'),
      style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
    ),
    if(busy) const Padding(padding:EdgeInsets.only(top:12),child:LinearProgressIndicator()),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
   ]))),

if (data != null) ...[
  const SizedBox(height: 22),
  Row(
    children: [
      Expanded(child: Text("Matching records",style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))),
      Chip(label:Text("${data!['matched_rows'] ?? rows.length} found")),
    ],
  ),
  if (rows.isNotEmpty) Card(
   child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Icon(Icons.auto_awesome),const SizedBox(width:8),Expanded(child:Text('Smart rank-based recommendations',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)))]),
    const SizedBox(height:6),
    Text('Suggestions are ranked using historical cutoff fit, your rank margin and the selected-district preference. This is a matching aid, not a college-quality rating or admission prediction.',style:TextStyle(fontSize:12,height:1.4,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height:10),
    ...rows.take(3).toList().asMap().entries.map((entry){
     final x=Map<String,dynamic>.from(entry.value as Map);
     final score=smartScore(x);
     final rawMargin=x['rank_difference'];
     final margin=rawMargin is num?rawMargin.toInt():int.tryParse('$rawMargin')??0;
     final group='${x['match_group']??''}';
     final reasons=<String>[];
     if('${x['status']??''}'=='Historically within cutoff') reasons.add('Within historical cutoff');
     if(margin>0) reasons.add('Rank buffer: $margin');
     if(group=='Selected district') reasons.add('Selected district');
     else if(group=='Other Karnataka districts') reasons.add('Other Karnataka district');
     return ListTile(
      contentPadding:EdgeInsets.zero,
      leading:CircleAvatar(child:Text('${entry.key+1}')),
      title:Text('${x['college']??'College'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)),
      subtitle:Text('${x['branch']??'Branch'}\n${reasons.isEmpty?'Historical fit needs careful review':reasons.join(' · ')}',style:const TextStyle(fontSize:11.5,height:1.35)),
      trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('$score/100',style:const TextStyle(fontWeight:FontWeight.w800)),const Text('match score',style:TextStyle(fontSize:9))]),
     );
    }),
   ])),
  ),
  Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
   crossAxisAlignment:CrossAxisAlignment.stretch,
   children:[
    TextField(controller:searchController,onChanged:(_)=>setState((){}),
     decoration:InputDecoration(labelText:'Search colleges',hintText:'College name, code, branch or district',
      prefixIcon:const Icon(Icons.search),
      suffixIcon:searchController.text.isEmpty?null:IconButton(tooltip:'Clear search',
       onPressed:()=>setState(()=>searchController.clear()),icon:const Icon(Icons.close)))),
    const SizedBox(height:10),
    DropdownButtonFormField<String>(initialValue:resultFilter,decoration:const InputDecoration(labelText:'Filter results'),
     items:['All results','Within historical cutoff','Outside historical cutoff','Selected district','Other Karnataka districts','District unverified']
      .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
     onChanged:(v){if(v!=null)setState(()=>resultFilter=v);}),
    const SizedBox(height:10),
    DropdownButtonFormField<String>(initialValue:sortBy,decoration:const InputDecoration(labelText:'Sort by'),
     items:['Recommended order','Smart match (recommended)','Closing rank: low to high','Closing rank: high to low','College name: A–Z']
      .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
     onChanged:(v){if(v!=null)setState(()=>sortBy=v);}),
    const SizedBox(height:6),
    Text('${rows.length} of ${sourceRows.length} records shown',
     style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurfaceVariant)),
   ],
  ))),
  if (data!['data_quality'] is Map) ...[
    Builder(builder:(context) {
      final q=Map<String,dynamic>.from(data!['data_quality'] as Map);
      return Card(child:Padding(padding:const EdgeInsets.all(14),child:Wrap(
        spacing:18,runSpacing:8,
        children:[
          _metric(context,"Rows parsed","${data!['uploaded_rows'] ?? '—'}"),
          _metric(context,"Categories","${q['categories_found'] ?? '—'}"),
          _metric(context,"Year(s)",(q['years'] as List? ?? const []).join(', ')),
        ],
      )));
    }),
  ],
  if (data!['district_notice'] != null)
    Padding(
      padding:const EdgeInsets.only(bottom:10),
      child:Text('${data!['district_notice']}',style:TextStyle(fontWeight:FontWeight.w700,color:Theme.of(context).colorScheme.primary)),
    ),
  if (data!['notice'] != null)
    Container(
      width:double.infinity,
      margin:const EdgeInsets.only(bottom:12),
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:Theme.of(context).colorScheme.secondaryContainer.withValues(alpha:.55),borderRadius:BorderRadius.circular(14)),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Icon(Icons.info_outline,size:19),
        const SizedBox(width:9),
        Expanded(child:Text('${data!['notice']}',style:const TextStyle(fontSize:12.5,height:1.4))),
      ]),
    ),
  if (rows.isEmpty)
    Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
      const Icon(Icons.search_off,size:38),
      const SizedBox(height:8),
      Text(sourceRows.isEmpty ? "${data!['message'] ?? 'No matching records.'}" : "No records match your search or selected filter.",textAlign:TextAlign.center),
    ]))),
  ...rows.asMap().entries.map((entry) {
    final index=entry.key;
    final v=entry.value;
    final x=Map<String,dynamic>.from(v as Map);
    final status='${x['status'] ?? ''}';
    final within=status=='Historically within cutoff';
    final margin=(x['rank_difference'] as num?)?.toInt() ?? 0;
String keyOf(Map item) =>
    '${item['college_code'] ?? item['college']}|${item['branch']}|${item['category']}|${item['cutoff_rank']}|${item['year']}|${item['round']}|${item['quota']}';    final isSaved=saved.any((item)=>keyOf(item)==keyOf(x));
    final scheme=Theme.of(context).colorScheme;
    final statusColor=within?const Color(0xff18794e):const Color(0xffa15c08);
    final statusText=within?'Within historical cutoff':'Outside historical cutoff';
    final group='${x['match_group'] ?? 'Karnataka'}';
    final showGroup=index==0 || '${(rows[index-1] as Map)['match_group'] ?? 'Karnataka'}'!=group;
    final groupCount=group=='Selected district'
        ? '${data!['district_match_count'] ?? 0}'
        : group=='Other Karnataka districts'
            ? '${(data!['statewide_fallback_count'] as int? ?? 0) - (data!['unverified_district_count'] as int? ?? 0)}'
            : group=='Karnataka fallback — district unverified'
                ? '${data!['unverified_district_count'] ?? 0}'
                : '${rows.length}';
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(showGroup) Padding(
        padding:const EdgeInsets.only(top:14,bottom:8),
        child:Row(children:[
          Expanded(child:Text(group,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800))),
          Chip(label:Text('$groupCount colleges'),visualDensity:VisualDensity.compact),
        ]),
      ),
      Card(
       clipBehavior: Clip.antiAlias,
       child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CollegeDetailsPage(
            college: x,
            studentRank: int.tryParse('${data!['rank'] ?? rank.text}') ?? int.tryParse(rank.text) ?? 0,
            isSaved: isSaved,
            onToggleSaved: () => _toggleSaved(x),
          ),
        )),
        child:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Expanded(child:Text('${x['college'] ?? 'College name unavailable'}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,height:1.25))),
            IconButton(
              tooltip:isSaved?'Remove from shortlist':'Save college',
              onPressed:()=>_toggleSaved(x),
              icon:Icon(isSaved?Icons.bookmark:Icons.bookmark_add_outlined,color:isSaved?scheme.primary:null),
            ),
          ]),
          const SizedBox(height:4),
          Text('${x['branch'] ?? 'Branch not provided'}',style:TextStyle(color:scheme.onSurfaceVariant,fontWeight:FontWeight.w600)),
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:8,children:[
            Container(
              padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
              decoration:BoxDecoration(color:statusColor.withValues(alpha:.10),borderRadius:BorderRadius.circular(30)),
              child:Text(statusText,style:TextStyle(color:statusColor,fontSize:11.5,fontWeight:FontWeight.w700)),
            ),
            Chip(label:Text('${x['category'] ?? cat}'),visualDensity:VisualDensity.compact),
            if(x['year']!=null) Chip(label:Text('${x['year']}'),visualDensity:VisualDensity.compact),
          ]),
          const SizedBox(height:12),
          Wrap(spacing:18,runSpacing:8,children:[
            _metric(context,"Closing rank","${x['cutoff_rank'] ?? '—'}"),
            _metric(context,"Your rank","${data!['rank'] ?? rank.text}"),
            _metric(context,margin>=0?"Rank margin":"Rank difference",margin>=0?"+$margin":"${margin.abs()} behind"),
          ]),
          if('${x['college_code'] ?? ''}'.isNotEmpty || '${x['quota'] ?? ''}'.isNotEmpty || '${x['round'] ?? ''}'.isNotEmpty || '${x['location'] ?? ''}'.isNotEmpty) ...[
            const Divider(height:22),
            Text([
              if(x['college_code']!=null) 'Code ${x['college_code']}',
              if(x['quota']!=null) '${x['quota']}',
              if(x['round']!=null) 'Round ${x['round']}',
              if(x['location']!=null) '${x['location']}',
            ].join('  ·  '),style:TextStyle(fontSize:11.5,color:scheme.onSurfaceVariant,height:1.4)),
          ],
        ]),
        ),
       ),
      ),
    ]);
  }),
] ,
    const SizedBox(height: 20),
    const Text(
      'Results show selected-district matches first, followed by statewide fallback. '
      'Districts inferred from addresses may be unverified; confirm college location and official KEA cutoffs.',
      style: TextStyle(fontSize: 12),
    ),
  ]),
);
}
}
