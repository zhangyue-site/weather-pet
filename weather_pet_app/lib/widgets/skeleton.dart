import 'dart:math';
import 'package:flutter/material.dart';

class Bone {
  final String name;
  final double length;
  double rotation;
  final List<Bone> children;

  Bone({
    required this.name,
    required this.length,
    this.rotation = 0,
    List<Bone>? children,
  }) : children = children ?? [];

  Bone addChild(Bone child) {
    children.add(child);
    return this;
  }
}

class Skeleton {
  late Bone root;
  late Bone head;
  late Bone body;
  late Bone leftArm;
  late Bone leftForearm;
  late Bone rightArm;
  late Bone rightForearm;
  late Bone leftLeg;
  late Bone leftShin;
  late Bone rightLeg;
  late Bone rightShin;

  Skeleton() {
    // 构建骨骼树
    leftShin = Bone(name: 'leftShin', length: 18);
    leftLeg = Bone(name: 'leftLeg', length: 20, children: [leftShin]);
    rightShin = Bone(name: 'rightShin', length: 18);
    rightLeg = Bone(name: 'rightLeg', length: 20, children: [rightShin]);

    leftForearm = Bone(name: 'leftForearm', length: 18);
    leftArm = Bone(name: 'leftArm', length: 22, children: [leftForearm]);
    rightForearm = Bone(name: 'rightForearm', length: 18);
    rightArm = Bone(name: 'rightArm', length: 22, children: [rightForearm]);

    head = Bone(name: 'head', length: 0);
    body = Bone(
      name: 'body',
      length: 45,
      children: [leftArm, rightArm, leftLeg, rightLeg, head],
    );
    root = body;
  }

  void reset() {
    _resetBone(root);
  }

  void _resetBone(Bone bone) {
    bone.rotation = 0;
    for (final child in bone.children) {
      _resetBone(child);
    }
  }
}

class BoneRenderer {
  static void render(Canvas canvas, Bone bone, Offset origin, double angle,
      {required Paint fillPaint, required Paint strokePaint, double scale = 1.0}) {
    final rad = angle + bone.rotation;
    final endX = origin.dx + cos(rad) * bone.length * scale;
    final endY = origin.dy + sin(rad) * bone.length * scale;
    final end = Offset(endX, endY);

    // 画骨骼段 (粗线表示身体部位)
    if (bone.name.contains('Arm') || bone.name.contains('Forearm')) {
      _drawLimb(canvas, origin, end, 6 * scale, fillPaint);
    } else if (bone.name.contains('Leg') || bone.name.contains('Shin')) {
      _drawLimb(canvas, origin, end, 7 * scale, fillPaint);
    } else if (bone.name == 'body') {
      _drawBody(canvas, origin, end, scale, fillPaint);
    }

    // 关节圆点
    canvas.drawCircle(origin, 3 * scale, strokePaint);

    // 递归画子骨骼
    for (final child in bone.children) {
      render(canvas, child, end, rad, fillPaint: fillPaint, strokePaint: strokePaint, scale: scale);
    }
  }

  static void _drawLimb(Canvas canvas, Offset from, Offset to, double width, Paint paint) {
    canvas.drawLine(from, to, paint..strokeWidth = width..strokeCap = StrokeCap.round);
  }

  static void _drawBody(Canvas canvas, Offset from, Offset to, double scale, Paint paint) {
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    canvas.drawOval(
      Rect.fromCenter(center: mid, width: 30 * scale, height: 45 * scale),
      paint,
    );
  }
}
