{ lib, stdenv, fetchFromGitHub, pkg-config, libtool
, bzip2Support ? true, bzip2
, zlibSupport ? true, zlib
, libX11Support ? !stdenv.hostPlatform.isMinGW, libX11
, libXtSupport ? !stdenv.hostPlatform.isMinGW, libXt
, fontconfigSupport ? true, fontconfig
, freetypeSupport ? true, freetype
, ghostscriptSupport ? false, ghostscript
, libjpegSupport ? true, libjpeg
, djvulibreSupport ? true, djvulibre
, lcms2Support ? true, lcms2
, openexrSupport ? !stdenv.hostPlatform.isMinGW, openexr
, libpngSupport ? true, libpng
, liblqr1Support ? true, liblqr1
, librsvgSupport ? !stdenv.hostPlatform.isMinGW, librsvg
, libtiffSupport ? true, libtiff
, libxml2Support ? true, libxml2
, openjpegSupport ? !stdenv.hostPlatform.isMinGW, openjpeg
, libwebpSupport ? !stdenv.hostPlatform.isMinGW, libwebp
, libheifSupport ? true, libheif
, libde265Support ? true, libde265
, fftw
, ApplicationServices, Foundation
, testers
}:

let
  arch =
    if stdenv.hostPlatform.system == "i686-linux" then "i686"
    else if stdenv.hostPlatform.system == "x86_64-linux" || stdenv.hostPlatform.system == "x86_64-darwin" then "x86-64"
    else if stdenv.hostPlatform.system == "armv7l-linux" then "armv7l"
    else if stdenv.hostPlatform.system == "aarch64-linux"  || stdenv.hostPlatform.system == "aarch64-darwin" then "aarch64"
    else if stdenv.hostPlatform.system == "powerpc64le-linux" then "ppc64le"
    else null;

  cfg = {
    version = "6.9.9-34";
    sha256 = "0sqrgyfi7i7x1akna95c1qhk9sxxswzm3pkssfi4w6v7bn24g25g";
    patches = [];
  };

in

stdenv.mkDerivation (finalAttrs: {
  pname = "imagemagick";
  inherit (cfg) version;

  src = fetchFromGitHub {
    owner = "ImageMagick";
    repo = "ImageMagick6";
    rev = cfg.version;
    inherit (cfg) sha256;
  };

  patches = [ ./imagetragick.patch ] ++ cfg.patches;

  outputs = [ "out" "dev" "doc" ]; # bin/ isn't really big
  outputMan = "out"; # it's tiny

  enableParallelBuilding = true;

  configureFlags =
    [ "--with-frozenpaths" ]
    ++ [ "--with-gcc-arch=${arch}" ]
    ++ lib.optional (librsvg != null) "--with-rsvg"
    ++ lib.optionals (ghostscript != null)
      [ "--with-gs-font-dir=${ghostscript}/share/ghostscript/fonts"
        "--with-gslib"
      ]
    ++ lib.optionals (stdenv.hostPlatform.isMinGW)
      [ "--enable-static" "--disable-shared" ] # due to libxml2 being without DLLs ATM
    ;

  nativeBuildInputs = [ pkg-config libtool ];

  buildInputs =
      [ zlib fontconfig freetype ghostscript
        libpng libtiff libxml2 libheif libde265
      ]
      ++ lib.optionals (!stdenv.hostPlatform.isMinGW)
        [ openexr librsvg openjpeg ]
      ++ lib.optional stdenv.isDarwin ApplicationServices;

  propagatedBuildInputs =
      [ bzip2 freetype libjpeg lcms2 fftw ]
      ++ lib.optionals (!stdenv.hostPlatform.isMinGW)
        [ libX11 libXext libXt libwebp ]
      ;

  doCheck = false; # fails 2 out of 76 tests

  postInstall = ''
    (cd "$dev/include" && ln -s ImageMagick* ImageMagick)
    moveToOutput "bin/*-config" "$dev"
    moveToOutput "lib/ImageMagick-*/config-Q16" "$dev" # includes configure params
    for file in "$dev"/bin/*-config; do
      substituteInPlace "$file" --replace "${pkgconfig}/bin/pkg-config -config" \
        ${pkgconfig}/bin/pkg-config
      substituteInPlace "$file" --replace ${pkgconfig}/bin/pkg-config \
        "PKG_CONFIG_PATH='$dev/lib/pkgconfig' '${pkgconfig}/bin/pkg-config'"
    done
  '' + lib.optionalString (ghostscript != null) ''
    for la in $out/lib/*.la; do
      sed 's|-lgs|-L${lib.getLib ghostscript}/lib -lgs|' -i $la
    done
  '';

  passthru.tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;

  meta = with lib; {
    homepage = "https://legacy.imagemagick.org/";
    changelog = "https://legacy.imagemagick.org/script/changelog.php";
    description = "A software suite to create, edit, compose, or convert bitmap images";
    pkgConfigModules = [ "ImageMagick" "MagickWand" ];
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = with maintainers; [ ];
    license = licenses.asl20;
  };
})
