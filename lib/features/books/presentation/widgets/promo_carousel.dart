import 'package:flutter/material.dart';

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.items});
  final List<String> items;
  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _page = PageController(viewportFraction: .92);
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 120,
        child: PageView.builder(
          controller: _page,
          onPageChanged: (i)=> setState(()=> _index=i),
          itemCount: widget.items.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFF8B5E34), Color(0xFFDDB892)]),
              ),
              child: Center(
                child: Text(widget.items[i], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(widget.items.length, (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i==_index? Colors.brown : Colors.brown.shade200,
        ),
      )))
    ]);
  }
}
