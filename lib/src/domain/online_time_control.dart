// SPDX-License-Identifier: GPL-3.0-or-later

class OnlineTimeControl {
  const OnlineTimeControl(
    this.label,
    this.baseMs, {
    this.incrementMs = 0,
    this.clockMode = 'live',
  });

  final String label;
  final int baseMs;
  final int incrementMs;
  final String clockMode;
  bool get isDaily => clockMode == 'daily';
}

const dailyTimeControl = OnlineTimeControl(
  'Daily · 24 hours per move',
  86400000,
  clockMode: 'daily',
);
const friendTimeControls = [dailyTimeControl, ...onlineTimeControls];
const onlineTimeControls = <OnlineTimeControl>[
  OnlineTimeControl('15 min · Rapid', 900000, incrementMs: 10000),
  OnlineTimeControl('30 min · Classical', 1800000),
  OnlineTimeControl('60 min · Classical', 3600000),
];

OnlineTimeControl closestOnlineTimeControl(int baseMs) =>
    onlineTimeControls.reduce(
      (closest, candidate) =>
          (candidate.baseMs - baseMs).abs() < (closest.baseMs - baseMs).abs()
          ? candidate
          : closest,
    );
