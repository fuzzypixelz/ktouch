{
  description = "KTouch, a touch typing tutor";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs {
          inherit system;
          config.allowUnsupportedSystem = true;
          overlays = if nixpkgs.lib.hasSuffix "-darwin" system then [
            (final: prev: {
              # KIO's ACL integration is optional, but nixpkgs currently adds
              # Linux-only acl/attr dependencies unconditionally.
              kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
                kauth = kprev.kauth.overrideAttrs (old: {
                  propagatedBuildInputs = nixpkgs.lib.filter
                    (dep: (dep.pname or "") != "polkit-qt-1")
                    old.propagatedBuildInputs;
                });
                kio = kprev.kio.overrideAttrs (old: {
                  buildInputs = nixpkgs.lib.filter
                    (dep: !(nixpkgs.lib.elem (dep.pname or "") [ "acl" "attr" ]))
                    old.buildInputs;
                  propagatedBuildInputs = nixpkgs.lib.filter
                    (dep: (dep.pname or "") != "kdoctools")
                    old.propagatedBuildInputs;
                });
                karchive = kprev.karchive.overrideAttrs (old: {
                  buildInputs = (old.buildInputs or [ ]) ++ [ final.bzip2 ];
                });
                extra-cmake-modules = kprev.extra-cmake-modules.overrideAttrs (old: {
                  postInstall = (old.postInstall or "") + ''
                    substituteInPlace $out/share/ECM/kde-modules/KDEMetaInfoPlatformCheck.cmake \
                      --replace-fail "message(FATAL_ERROR" "message(WARNING"
                  '';
                });
                kguiaddons = kprev.kguiaddons.overrideAttrs (old: {
                  buildInputs = nixpkgs.lib.filter
                    (dep: !nixpkgs.lib.elem (dep.pname or "") [ "qtwayland" ]) old.buildInputs;
                  propagatedBuildInputs = nixpkgs.lib.filter
                    (dep: !nixpkgs.lib.elem (dep.pname or "") [ "wayland" "wayland-protocols" "plasma-wayland-protocols" ])
                    old.propagatedBuildInputs;
                });
                kwindowsystem = kprev.kwindowsystem.overrideAttrs (old: {
                  buildInputs = nixpkgs.lib.filter
                    (dep: (dep.pname or "") != "qtwayland") old.buildInputs;
                  propagatedBuildInputs = nixpkgs.lib.filter
                    (dep: !nixpkgs.lib.elem (dep.pname or "") [ "wayland" "wayland-protocols" "plasma-wayland-protocols" ])
                    old.propagatedBuildInputs;
                });
                kglobalaccel = kprev.kglobalaccel.overrideAttrs (old: {
                  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DWITH_X11=OFF" ];
                });
                kservice = kprev.kservice.overrideAttrs (old: {
                  propagatedBuildInputs = nixpkgs.lib.filter
                    (dep: (dep.pname or "") != "kdoctools")
                    old.propagatedBuildInputs;
                });
                kwallet = kprev.kwallet.overrideAttrs (old: {
                  buildInputs = nixpkgs.lib.filter
                    (dep: (dep.pname or "") != "kdoctools") old.buildInputs;
                  propagatedBuildInputs = nixpkgs.lib.filter
                    (dep: (dep.pname or "") != "kdoctools")
                    old.propagatedBuildInputs;
                });
              });
            })
          ] else [ ];
        }));
    in {
      packages = forAllSystems (pkgs: {
        default = pkgs.stdenv.mkDerivation {
          pname = "ktouch";
          version = "26.11.70";
          src = ./.;

          nativeBuildInputs = with pkgs; [
            cmake
            kdePackages.extra-cmake-modules
            gettext
            qt6Packages.qttools
            qt6Packages.wrapQtAppsHook
          ];

          buildInputs = with pkgs; [
            qt6Packages.qtbase
            qt6Packages.qtdeclarative
            kdePackages.kcompletion
            kdePackages.kconfig
            kdePackages.kconfigwidgets
            kdePackages.kcoreaddons
            kdePackages.ki18n
            kdePackages.kitemviews
            kdePackages.kcmutils
            kdePackages.ktextwidgets
            kdePackages.kwidgetsaddons
            kdePackages.kwindowsystem
            kdePackages.kxmlgui
            kdePackages.kqtquickcharts
            libxml2
          ];

          cmakeFlags = [
            "-DWITHOUT_X11=ON"
            "-DKF_IGNORE_PLATFORM_CHECK=TRUE"
          ];

          postInstall = ''
            mkdir -p $out/bin
            ln -s $out/Applications/KDE/ktouch.app/Contents/MacOS/ktouch $out/bin/ktouch
          '';
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        };
      });
    };
}
