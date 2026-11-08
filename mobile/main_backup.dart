import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const cats=['1G','1K','1R','2AG','2AK','2AR','2BG','2BK','2BR','3AG','3AK','3AR','3BG','3BK','3BR','GM','GMK','GMP','GMR','NRI','OPN','OTH','S1G','S1K','S1R','S2G','S2K','S2R','S3G','S3K','S3R','S4G','S4K','S4R','STG','STK','STR'];
void main()=>runApp(const KcetApp());
class KcetApp extends StatelessWidget { const KcetApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(title:'KCET College Predictor',debugShowCheckedModeBanner:false,theme:ThemeData(colorSchemeSeed:const Color(0xff2448d8),useMaterial3:true),home:const Predictor());}
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
 final api=const String.fromEnvironment('KCET_API_URL',defaultValue:'http://10.0.2.2:8000');
 Future<void> pick()async{final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['csv','xlsx','xls','pdf'],withData:true);if(r!=null&&r.files.isNotEmpty)setState(()=>file=r.files.single);}
 Future<void> runPrediction()async{
  final n=int.tryParse(rank.text.trim());if(n==null||n<1){setState(()=>error='Enter a valid rank.');return;}if(file==null){setState(()=>error='Choose a cutoff file first.');return;}
  setState(()=>{busy=true,error=null,data=null});
  try{final req=http.MultipartRequest('POST',Uri.parse('$api/predict'));req.fields.addAll({'rank':'$n','category':cat,'branch':branch.text.trim(),'location':district.text.trim(),'round_name':round.text.trim()});
   final f=file!;if(f.bytes!=null){req.files.add(http.MultipartFile.fromBytes('file',f.bytes!,filename:f.name));}else if(f.path!=null){req.files.add(await http.MultipartFile.fromPath('file',f.path!,filename:f.name));}else{throw Exception('Cannot read file; choose it again.');}
   final res=await req.send().timeout(const Duration(seconds:120));final body=await res.stream.bytesToString();final json=jsonDecode(body);
   if(res.statusCode<200||res.statusCode>=300)throw Exception(json is Map?json['detail']??'Prediction failed':'Prediction failed');
   setState(()=>data=Map<String,dynamic>.from(json as Map));
  }catch(e){setState(()=>error='API request failed: $e');}finally{setState(()=>busy=false);}
 }
 @override void dispose(){rank.dispose();branch.dispose();district.dispose();round.dispose();email.dispose();password.dispose();super.dispose();}
 @override Widget build(BuildContext context){final rows=data?['results'] as List? ?? const [];
  return Scaffold(appBar:AppBar(title:const Text('KCET College Predictor'),actions:[IconButton(tooltip:'My shortlist',onPressed:()=>showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[Text('My Shortlist (${saved.length})',style:Theme.of(context).textTheme.titleLarge),...saved.map((x)=>ListTile(title:Text('${x['college']??'College'}'),subtitle:Text('${x['branch']??''} · Closing rank ${x['cutoff_rank']??'—'}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:(){_toggleSaved(x);Navigator.pop(ctx);}))) ]))),icon:const Icon(Icons.bookmarks_outlined))]),body:ListView(padding:const EdgeInsets.all(16),children:[
   Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(token==null?'Optional account · Sync shortlist across devices':'Signed in: ${accountEmail??''}',style:const TextStyle(fontWeight:FontWeight.bold)),if(token==null)...[TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),const SizedBox(height:8),TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password (8+ characters)',border:OutlineInputBorder())),const SizedBox(height:8),Row(children:[Expanded(child:FilledButton(onPressed:authBusy?null:_auth,child:Text(authBusy?'Please wait…':authMode=='register'?'Create account':'Sign in'))),TextButton(onPressed:()=>setState(()=>authMode=authMode=='login'?'register':'login'),child:Text(authMode=='login'?'Register':'Sign in'))])]else TextButton(onPressed:()async{final p=await SharedPreferences.getInstance();await p.remove('kcet_token');await p.remove('kcet_email');setState(()=>{token=null,accountEmail=null,cloudMessage='Signed out. Local shortlist remains.'});},child:const Text('Sign out')),if(cloudMessage!=null)Text(cloudMessage!,style:const TextStyle(fontSize:12))]))),
   const Text('Find colleges that fit your rank',style:TextStyle(fontSize:25,fontWeight:FontWeight.bold)),const SizedBox(height:8),
   const Text('Compare your rank with uploaded historical cutoffs. This is not an admission guarantee.'),const SizedBox(height:16),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    TextField(controller:rank,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'KCET rank',border:OutlineInputBorder())),
    const SizedBox(height:12),DropdownButtonFormField<String>(value:cat,decoration:const InputDecoration(labelText:'Category',border:OutlineInputBorder()),items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x){if(x!=null)setState(()=>cat=x);}),
    const SizedBox(height:12),TextField(controller:branch,decoration:const InputDecoration(labelText:'Branch filter (optional)',hintText:'Computer Science',border:OutlineInputBorder())),
    const SizedBox(height:12),TextField(controller:district,decoration:const InputDecoration(labelText:'District / location (optional)',hintText:'Bengaluru',border:OutlineInputBorder())),
    const SizedBox(height:12),TextField(controller:round,decoration:const InputDecoration(labelText:'Counselling round (optional)',border:OutlineInputBorder())),
    const SizedBox(height:12),OutlinedButton.icon(onPressed:busy?null:pick,icon:const Icon(Icons.upload_file),label:Text(file?.name??'Choose cutoff file')),
    const SizedBox(height:12),FilledButton(onPressed:busy?null:runPrediction,child:Text(busy?'Analyzing…':'Predict colleges')),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
   ]))),

if (data != null) ...[
  const SizedBox(height: 16),
  Text(
    "Results (${data!['matched_rows'] ?? rows.length})",
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
    ),
  ),
  if (data!['notice'] != null)
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text('${data!['notice']}'),
    ),
  if (rows.isEmpty)
    Text("${data!['message'] ?? 'No matching records.'}"),
  ...rows.map((v) {
    final x = Map<String, dynamic>.from(v as Map);
    final ok = x['status'] == 'Historically within cutoff';
    final keyOf = (Map item) =>
        '${item['college_code'] ?? item['college']}|'
        '${item['branch']}|${item['category']}|'
        '${item['cutoff_rank']}|${item['year']}|'
        '${item['round']}|${item['quota']}';
    final isSaved = saved.any((item) => keyOf(item) == keyOf(x));

    return Card(
      child: ListTile(
        title: Text(
          '${x['college'] ?? 'College'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${x['branch']}\n'
          'Code: ${x['college_code'] ?? '—'} · '
          'Category: ${x['category'] ?? cat}\n'
          'Closing rank: ${x['cutoff_rank'] ?? '—'} · '
          'Year: ${x['year'] ?? '—'}\n'
          '${x['location'] ?? ''} ${x['quota'] ?? ''}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.info_outline,
              color: ok ? Colors.green : Colors.orange,
            ),
            IconButton(
              tooltip: 'Save college',
              onPressed: () => _toggleSaved(x),
              icon: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
              ),
            ),
          ],
        ),
      ),
    );
  }),
    const SizedBox(height: 20),
    const Text(
      'District filtering searches location/address text found in the uploaded file. '
      'Verify cutoffs against official KEA data.',
      style: TextStyle(fontSize: 12),
    ),
  ]),
);
}
}
