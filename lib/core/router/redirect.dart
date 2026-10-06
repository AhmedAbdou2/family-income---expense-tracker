/// Navigation / flow statuses used by the router redirect. Kept as a pure
/// function (see `appRedirect`) so it can be unit tested without widgets.
const String splashRoute = '/splash';

const Set<String> authRoutes = {'/sign-in', '/sign-up', '/forgot-password'};
const Set<String> setupRoutes = {'/setup', '/setup/create', '/setup/join'};

/// Decides where (if anywhere) the router should send the user.
///
/// Flow:
///   resolving auth            -> /splash
///   signed out                -> /sign-in
///   signed in, no household   -> /setup (create or join)
///   signed in, has household  -> app shell ('/')
String? appRedirect({
  required bool authLoading,
  required bool signedIn,
  required bool membershipLoading,
  required bool hasMembership,
  required String location,
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

  if (authRoutes.contains(location) ||
      location == splashRoute ||
      setupRoutes.contains(location)) {
    return '/';
  }
  return null;
}
