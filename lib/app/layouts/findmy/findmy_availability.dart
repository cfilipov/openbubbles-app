/// Navigation is a capability, not a check that the item daemon is connected.
/// Direct Apple connections can show errors/retry inside the map page, while
/// server-backed connections must still advertise Find My support.
bool canOpenFindMy({required bool directConnection, required bool serverSupportsFindMy}) =>
    directConnection || serverSupportsFindMy;
