import 'package:flutter/material.dart';

class ServiceRequestPopupClipper extends CustomClipper<Path> {
  final double borderRadius;
  final double stepExtension; // How much wider the bottom section is

  const ServiceRequestPopupClipper({
    this.borderRadius = 24.0,   // Smooth, prominent corner rounding
    this.stepExtension = 16.0,  // The outward width step on each side
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double w = size.width;
    final double h = size.height;
    
    // The transition happens roughly 60% down the card
    final double transitionTop = h * 0.58;
    final double transitionBottom = h * 0.62;

    // --- TOP NARROW SECTION ---
    // Start at Top-Left
    path.moveTo(stepExtension + borderRadius, 0);
    
    // Top Edge to Top-Right
    path.lineTo(w - stepExtension - borderRadius, 0);
    path.quadraticBezierTo(w - stepExtension, 0, w - stepExtension, borderRadius);

    // Right Edge (Narrow top part) going down
    path.lineTo(w - stepExtension, transitionTop - borderRadius);
    
    // --- RIGHT SIDE OUTWARD STEP ---
    // Curve out to start the shoulder transition
    path.quadraticBezierTo(
      w - stepExtension, transitionTop, 
      w - (stepExtension / 2), (transitionTop + transitionBottom) / 2
    );
    // Curve down into the wider bottom section
    path.quadraticBezierTo(
      w, transitionBottom, 
      w, transitionBottom + borderRadius
    );

    // --- BOTTOM WIDER SECTION ---
    // Right Edge (Wider bottom part) going down
    path.lineTo(w, h - borderRadius);
    
    // Bottom-Right Corner
    path.quadraticBezierTo(w, h, w - borderRadius, h);

    // Bottom Edge going left
    path.lineTo(borderRadius, h);
    
    // Bottom-Left Corner
    path.quadraticBezierTo(0, h, 0, h - borderRadius);

    // Left Edge (Wider bottom part) going up
    path.lineTo(0, transitionBottom + borderRadius);

    // --- LEFT SIDE INWARD STEP (Mirroring the right side) ---
    // Curve inward to start the shoulder transition
    path.quadraticBezierTo(
      0, transitionBottom, 
      stepExtension / 2, (transitionTop + transitionBottom) / 2
    );
    // Curve up into the narrower top section
    path.quadraticBezierTo(
      stepExtension, transitionTop, 
      stepExtension, transitionTop - borderRadius
    );

    // Left Edge (Narrow top part) going up
    path.lineTo(stepExtension, borderRadius);
    
    // Top-Left Corner
    path.quadraticBezierTo(stepExtension, 0, stepExtension + borderRadius, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

