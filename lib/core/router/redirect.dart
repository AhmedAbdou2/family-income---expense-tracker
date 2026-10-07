/// Navigation / flow statuses used by the router redirect. Kept as a pure
/// function (see `appRedirect`) so it can be unit tested without widgets.
const String splashRoute = '/splash';

/// Route for a login that has a household but no linked person yet.
const String claimRoute = '/claim';

const Set<String> authRoutes = {'/sign-in', '/sign-up', '/forgot-password'};
const Set<String> setupRoutes = {'/setup', '/setup/create', '/setup/join'};

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

  if (authRoutes.contains(location) ||
      location == splashRoute ||
      location == claimRoute ||
      setupRoutes.contains(location)) {
    return '/';
  }
  return null;
}
