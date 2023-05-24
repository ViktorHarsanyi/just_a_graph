import 'package:flutter/material.dart';
import 'package:just_a_graph/graph/rtp_graph.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        extendBody: true,
        body:
          AspectRatio(aspectRatio: 1.586,
          child: Container(
              padding: const EdgeInsets.all(4.0),
              color: const Color(0xff141414),
              child: RTPGraph(
                labelItemBuilder: (offset) => Container(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(

                    '${offset.dx}',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                points: List.generate(
                  10,
                  (index) => GraphData(
                    color: index % 2 == 0 ? const Color(0xff31b18b) : const Color(0xffaf72c6),
                    offset: Offset(
                      Random().nextDouble(),
                      index + 1.0,
                    ),
                  ),
                ),
              )),
        ),
      ),
    );
  }
}
