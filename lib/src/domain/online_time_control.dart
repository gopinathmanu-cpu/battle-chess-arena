// SPDX-License-Identifier: GPL-3.0-or-later

class OnlineTimeControl {
  const OnlineTimeControl(this.label, this.baseMs);

  final String label;
  final int baseMs;
}

const onlineTimeControls = <OnlineTimeControl>[
  OnlineTimeControl('15 min · Rapid', 900000),
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
