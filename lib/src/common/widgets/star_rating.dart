import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final Color color;
  final Color unratedColor;
  final bool allowHalfStar;
  final ValueChanged<int>? onRatingChanged;
  final MainAxisAlignment mainAxisAlignment;
  
  const StarRating({
    Key? key,
    required this.rating,
    this.starCount = 5,
    this.size = 24,
    this.color = Colors.amber,
    this.unratedColor = Colors.grey,
    this.allowHalfStar = true,
    this.onRatingChanged,
    this.mainAxisAlignment = MainAxisAlignment.start,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: List.generate(starCount, (index) {
        final starPosition = index + 1;
        final isHalfStar = allowHalfStar && 
            (starPosition > rating && starPosition - 0.5 <= rating);
        final isFullStar = starPosition <= rating;
        
        return GestureDetector(
          onTap: onRatingChanged != null 
              ? () => onRatingChanged!(starPosition) 
              : null,
          child: Icon(
            isFullStar ? Icons.star 
              : isHalfStar ? Icons.star_half 
              : Icons.star_border,
            color: isFullStar || isHalfStar ? color : unratedColor,
            size: size,
          ),
        );
      }),
    );
  }
}