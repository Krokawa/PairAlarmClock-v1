import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'リアルタイム取得'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class _MyHomePageState extends State<MyHomePage> {
  String now_time = DateFormat('HH:mm:ss').format(DateTime.now());
  String? alarm_time;
  late AudioPlayer audioPlayer;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ja');
    Timer.periodic(Duration(seconds: 1), _onTimer);
    _initializeNotifications();
    _getAlarmTime();
    audioPlayer = AudioPlayer();
  }

  bool isAlarmRinging = false;
  void _onTimer(Timer timer) {
    var new_time = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      now_time = new_time;
    });

    var now = DateTime.now();
    var alarmTime = alarm_time?.split(':');
    if (!isAlarmRinging && alarmTime != null &&
        now.hour == int.parse(alarmTime[0]) &&
        now.minute == int.parse(alarmTime[1])) {
      isAlarmRinging = true;
      _showNotificationDialog();
      print('Alarm is ringing');
      _playAlarm();
    }
  }

  Future<void> _showNotificationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('アラーム'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('時間になりました'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
                isAlarmRinging = false; // Reset the alarm status
              },
            ),
          ],
        );
      },
    );
  }

  void _initializeNotifications() {
    flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('app_icon'),
        iOS: IOSInitializationSettings(),
      ),
      onSelectNotification: (String? payload) async {
        await _showNotificationDialog();
      },
    );
  }

  void _getAlarmTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedAlarmTime = prefs.getString('alarm_time');
    setState(() {
      alarm_time = savedAlarmTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat.yMMMMEEEEd('ja').format(DateTime.now()),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 10,
            ),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.yellow[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text("ただいまの時刻"),
                  Text(
                    '$now_time',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  Text('アラームの時間: '),
                  Text(
                    '${alarm_time ?? ''}',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
            ElevatedButton(
              child: const Text('アラームを設定する'),
              onPressed: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    _scheduleNotification(picked);
                    alarm_time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    print('Alarm time set to: $alarm_time');
                  });
                }
              },
            ),
            ElevatedButton(
              child: const Text('停止'),
              onPressed: () {
                FlutterRingtonePlayer.stop();
                audioPlayer.stop();
              },
            )
          ],
        ),
      ),
    );
  }

  Future<void> _scheduleNotification(TimeOfDay pickedTime) async {
    var time = Time(pickedTime.hour, pickedTime.minute, 0);
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm_notification_channel',
      'Alarm Notification Channel',
      channelDescription: 'Channel for alarm notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
    );
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'アラーム',
      'アラームが鳴ります',
      _nextInstanceOfTime(time),
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(
        'alarm_time',
        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}:00');
  }

  tz.TZDateTime _nextInstanceOfTime(Time time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  void _playAlarm() async {
    await audioPlayer.play('assets/Morning.mp3');
  }
}
