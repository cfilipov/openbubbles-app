String? findMyItemBatteryStatus(int? reportStatus) {
  if (reportStatus == null) return null;

  return switch (reportStatus & 0xC0) {
    0x80 => "Low Battery",
    0xC0 => "Very Low Battery",
    _ => null,
  };
}
