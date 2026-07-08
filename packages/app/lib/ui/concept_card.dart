import 'package:flutter/material.dart';

/// 게임 컨셉에 맞춘 카드형 상세 설명 다이얼로그(다크그린 + 허니 테두리).
/// 능력치·재화 등 "무엇이고 어디에 쓰이는지" 안내를 통일된 카드로 보여준다.
void showConceptCard(
  BuildContext context, {
  required Widget iconBox,
  required String title,
  required String body,
  required String closeLabel,
  String? subtitle,
}) {
  showDialog<void>(
    context: context,
    barrierColor: const Color(0xAA000000),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF21F2E13), Color(0xF20E1608)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x88EBA52F), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                iconBox,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFFEBA52F),
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0x33EBA52F)),
            ),
            Text(
              body,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEBA52F),
                ),
                child: Text(closeLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
