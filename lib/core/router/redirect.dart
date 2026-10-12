/// Navigation / flow statuses used by the router redirect. Kept as a pure
/// function (see `appRedirect`) so it can be unit tested without widgets.
const String splashRoute = '/splash';

/// Route for a login that has a household but no linked person yet.
const String claimRoute = '/claim';

const Set<String> authRoutes = {'/sign-in', '/sign-up', '/forgot-password'};
const Set<String> setupRoutes = {'/setup', '/setup/create', '/setup/join'};

/// Routes only owner/adult logins may open. Vehicles (with fuel/maintenance),
/// pets, recurring fixed commitments, budgets and reports are adult features;
/// a child landing here (e.g. a stale bookmark) is sent back to the dashboard.
const Set<String> adultOnlyRoutes = {
  '/vehicles',
  '/recurring',
  '/pets',
  '/budgets',
  '/reports',
};

bool _isAdultOnly(String location) {
  for (final route in adultOnlyRoutes) {
    if (location == route || location.startsWith('$route/')) return true;
  }
  return false;
}

/// Decides where (if anywhere) the router should send the user.
///
/// Flow:
///   resolving auth            -> /splash
///   signed out                -> /sign-in
///   signed in, no household   -> /setup (create or join)
///   signed in, household, linked person   -> app shell ('/')
///   signed in, household, no linked person-> /claim
String? appRedirect({
  required bool authLoading,
  required bool signedIn,
  required bool membershipLoading,
  required bool hasMembership,
  required String location,
  bool memberLoading = false,
  bool hasLinkedMember = true,
  bool isAdult = true,
}) {
  if (authLoading) {
    return location == splashRoute ? null : splashRoute;
  }

  if (!signedIn) {
    return authRoutes.contains(location) ? null : '/sign-in';
  }

  if (membershipLoading) {
    return location == splashRoute ? null : splashRoute;
  }

  if (!hasMembership) {
    return setupRoutes.contains(location) ? null : '/setup';
  }

  if (memberLoading) {
    return location == splashRoute ? null : splashRoute;
  }

  if (!hasLinkedMember) {
    return location == claimRoute ? null : claimRoute;
  }

  if (!isAdult && _isAdultOnly(location)) {
    return '/';
  }

  if (authRoutes.contains(location) ||
      location == splashRoute ||
      location == claimRoute ||
      setupRoutes.contains(location)) {
    return '/';
  }
  return null;
}
