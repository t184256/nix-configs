# pi-system-reminders: reactive system reminders

_: prev: {
  pi-system-reminders = prev.buildNpmPackage {
    pname = "pi-system-reminders";
    version = "0.1.3";

    src = prev.fetchFromGitHub {
      owner = "Michaelliv";
      repo = "pi-system-reminders";
      rev = "677c4237bb2ce465afe97fd18f04c619151862e1";
      hash = "sha256-1H3clBZEkNHtmKraMLUHMLL3lBc5jw7vN/VuZirFn2w=";
    };

    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-9tBoO5q9qOTVSR0strd5GEEePj2kp8Qj2/MwrsMc4Vk=";
    npmFlags = [ "--legacy-peer-deps" ]; # pi-coding-agent is a runtime one
    dontNpmBuild = true;
  };
}
