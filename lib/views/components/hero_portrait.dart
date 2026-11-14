import 'package:flutter/material.dart';
import '../../models/hero_model.dart';

/// 武将名 -> assets/heroes 下的文件名（ASCII，避免中文路径在打包/各平台上的兼容问题）
const Map<String, String> heroAssetIds = {
  '刘备': 'liubei',
  '曹操': 'caocao',
  '孙权': 'sunquan',
  '周处': 'zhouchu',
  '谋关羽': 'mou_guanyu',
  '谋张辽': 'mou_zhangliao',
  '谋袁绍': 'mou_yuanshao',
  '谋吕布': 'mou_lvbu',
  '谋华雄': 'mou_huaxiong',
  '谋张飞': 'mou_zhangfei',
  '谋赵云': 'mou_zhaoyun',
  '谋甄姬': 'mou_zhenji',
  '谋大乔': 'mou_daqiao',
  '谋田豫': 'mou_tianyu',
  '谋黄忠': 'mou_huangzhong',
  '谋陈宫': 'mou_chengong',
  '谋曹操': 'mou_caocao',
  '谋周瑜': 'mou_zhouyu',
  '谋曹仁': 'mou_caoren',
  '谋于禁': 'mou_yujin',
  '谋贾诩': 'mou_jiaxu',
  '谋马超': 'mou_machao',
  '谋曹丕': 'mou_caopi',
  '谋张角': 'mou_zhangjiao',
};

/// 武将将面立绘。找不到图片时退化为势力色渐变 + 姓名首字。
class HeroPortrait extends StatelessWidget {
  final String hero;
  final BoxFit fit;
  final bool showFallbackText;

  const HeroPortrait({
    super.key,
    required this.hero,
    this.fit = BoxFit.cover,
    this.showFallbackText = true,
  });

  Widget _fallback() {
    final color = HeroModel.forceColor(_forceOf(hero));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.85), Colors.black87],
        ),
      ),
      child: showFallbackText
          ? Center(
              child: Text(
                hero.isNotEmpty ? hero.substring(hero.length - 1) : '武',
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = heroAssetIds[hero];
    if (id == null) return _fallback();
    return Image.asset(
      'assets/heroes/$id.jpg',
      fit: fit,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stack) => _fallback(),
    );
  }

  /// 仅用于图片缺失时的配色推测
  static String _forceOf(String hero) {
    const shu = ['刘备', '关羽', '张飞', '赵云', '黄忠', '周处', '诸葛亮'];
    const wei = ['曹操', '张辽', '甄姬', '田豫', '夏侯', '郭嘉', '荀彧'];
    const wu = ['孙权', '大乔', '小乔', '周瑜', '陆逊', '黄盖'];
    for (final n in shu) {
      if (hero.contains(n)) return '蜀';
    }
    for (final n in wei) {
      if (hero.contains(n)) return '魏';
    }
    for (final n in wu) {
      if (hero.contains(n)) return '吴';
    }
    return '群';
  }
}
