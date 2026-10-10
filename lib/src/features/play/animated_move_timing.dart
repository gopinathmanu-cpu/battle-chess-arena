// SPDX-License-Identifier: GPL-3.0-or-later

/// Shared presentation timing for the live arena and its board overlay.
/// Game state and online acceptance remain independent of this visual clock.
const animatedMoveDuration = Duration(milliseconds: 850);
const animatedSelectionDuration = Duration(milliseconds: 180);
const animatedMoveImpactFraction = .46;
