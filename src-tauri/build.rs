fn main() {
  #[cfg(feature = "tauri-mode")]
  {
    // Pick the capability file to match the compiled feature set.
    //
    // tauri-build resolves every permission in every capability it parses, so
    // the default glob ("./capabilities/**/*") would pull in default.json and
    // fail an App Store build on `updater:default` — that permission set only
    // exists when tauri-plugin-updater is compiled in. Selecting a single file
    // keeps the two builds independent.
    //
    // Note that `app.security.capabilities` in tauri.conf.json cannot do this
    // job: it filters which capabilities apply at runtime, but every file in
    // the directory is still parsed and validated at build time.
    #[cfg(feature = "self-updater")]
    let capabilities = "./capabilities/default.json";
    #[cfg(not(feature = "self-updater"))]
    let capabilities = "./capabilities/appstore.json";

    // tauri-build only emits this itself when using the default glob.
    println!("cargo:rerun-if-changed=capabilities");

    tauri_build::try_build(
      tauri_build::Attributes::new().capabilities_path_pattern(capabilities),
    )
    .expect("failed to run tauri-build");
  }
}
