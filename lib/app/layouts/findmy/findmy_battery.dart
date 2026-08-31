String? findMyItemBatteryStatus(int? reportStatus) {
  if (reportStatus == null) return null;

  return switch (reportStatus & 0xC0) {
    0x80 => "Low Battery",
    0xC0 => "Very Low Battery",
    _ => null,
  };
}

String? findMyBatteryWarning({
  required bool isConsideredAccessory,
  required String? batteryStatus,
}) {
  if (!isConsideredAccessory) return null;

  return switch (batteryStatus?.toLowerCase()) {
    "low battery" || "very low battery" => batteryStatus,
    _ => null,
  };
}
