{ pkgs }:

let
  version = "1.1.3";
  src = pkgs.fetchFromGitHub {
    owner = "trougnouf";
    repo = "cfait";
    rev = "v${version}";
    hash = "sha256-bWpxmx5/l3lR+Zy+9+1QaiCHtFlYXFdsb7G8DOIAp44=";
  };

  # Vulkan/Wayland/X11 libs dlopen'd at runtime by iced/wgpu (the GUI).
  runtimeLibs = with pkgs; [
    vulkan-loader
    wayland
    libxkbcommon
    libGL
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in
pkgs.rustPlatform.buildRustPackage {
  pname = "cfait";
  inherit version src;

  cargoHash = "sha256-QTOnTsxt4/2CKEaDwCalkcR0/8IfslhZtpSAK82Lw04=";

  # tui -> `cfait` binary, gui -> `cfait-gui` binary (iced). rfd uses the
  # xdg-portal backend, so no GTK is needed at build time.
  buildFeatures = [ "tui" "gui" ];

  # Test suite exercises CalDAV sync, which needs network/a live server.
  doCheck = false;

  # rustc overflows its default stack compiling the deeply-nested generics in
  # the cfait lib crate; give it a larger one (as rustc itself suggests).
  env.RUST_MIN_STACK = "33554432";

  # cmake + nasm build aws-lc-sys (rustls' default crypto backend) from source.
  nativeBuildInputs = with pkgs; [ pkg-config makeWrapper cmake nasm ];

  postInstall = ''
    wrapProgram $out/bin/cfait-gui \
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath runtimeLibs}
  '';

  meta = with pkgs.lib; {
    description = "Powerful, fast and elegant task/TODO manager (GUI & TUI) with CalDAV sync";
    homepage = "https://github.com/trougnouf/cfait";
    license = licenses.gpl3Plus;
    mainProgram = "cfait";
    platforms = platforms.linux;
  };
}
