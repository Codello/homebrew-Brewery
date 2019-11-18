class LatexRequirement < Requirement
  fatal true

  satisfy :build_env => false do
    metafont = which("mf-nowin") || which("mf") || which("mfw") || which("mfont")
    metapost = which("mpost") || which("metapost")
    kpsewhich = which("kpsewhich")
    metafont && metapost && kpsewhich
  end

  def message; <<~EOS
    A working LaTeX installation is required for building LilyPond. Install it via one of:
      brew cask install mactex
      brew cask install basictex
  EOS
  end
end

class CyrillicRequirement < Requirement
  fatal false

  satisfy :build_env => false do
    kpsewhich = which("kpsewhich")
    system kpsewhich, "lcy.sty", :out => File::NULL if kpsewhich
  end

  def message; <<~EOS
    The LaTeX 'cyrillic' package should be installed before building LilyPond. Install it via:
      tlmgr install cyrillic
    The installation may still work without this dependency.
  EOS
  end
end

class Lilypond < Formula
  desc "... music notation for everyone"
  homepage "https://lilypond.org"

  head "git://git.savannah.gnu.org/lilypond.git"

  stable do
    url "http://lilypond.org/download/sources/v2.18/lilypond-2.18.2.tar.gz"
    sha256 "329d733765b0ba7be1878ae3f457dbbb875cc2840d2b75af4afc48c9454fba07"
  end

  devel do
    url "http://lilypond.org/download/sources/v2.19/lilypond-2.19.83.tar.gz"
    sha256 "96ba4f4b342d21057ad74d85d647aea7e47a5c24f895127c2b3553a252738fb3"
  end

  depends_on "autoconf" => :build
  depends_on "bison" => :build
  depends_on CyrillicRequirement => :build if build.devel?
  depends_on "flex" => :build
  depends_on "fontforge" => :build
  depends_on "gcc" => :build
  depends_on "gettext" => :build
  depends_on LatexRequirement => :build
  uses_from_macos "make" => :build
  uses_from_macos "perl" => :build
  depends_on "pkg-config" => :build
  depends_on "python@2" => :build
  depends_on "t1utils" => :build
  depends_on "texinfo" => :build

  uses_from_macos "python"
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "ghostscript"
  depends_on "pango"
  depends_on "sadhen/sadhen/guile@1.8"

  depends_on "codello/brewery/extractpdfmark" => :recommended

  fails_with :clang do
    build 1100
    cause "LilyPond uses some GCC specific C++ extensions and must be compiled with GCC"
  end

  resource "TeX Gyre Font Collection" do
    url "http://www.gust.org.pl/projects/e-foundry/tex-gyre/whole/tg2_501otf.zip"
    sha256 "d7f8be5317bec4e644cf16c5abf876abeeb83c43dbec0ccb4eee4516b73b1bbe"
  end

  resource "New Century Schoolbook Fonts" do
    url "https://github.com/Distrotech/gs-fonts/archive/4a4f4372b5378ac7181f9aca673437bdd51c36c4.tar.gz"
    sha256 "53d6d5fdbda26fbb978923f18f65bb825f79e04609df46dd6eec819c15c93474"
  end

  def install
    font_dir = Pathname("fonts").expand_path
    if build.stable?
      resource("New Century Schoolbook Fonts").stage do
        font_dir.install Dir["usr/share/ghostscript/fonts/*"]
      end
    else
      font_dir.install resource("TeX Gyre Font Collection")
    end

    system "./autogen.sh", "--noconfigure"
    mkdir "build" do
      system "../configure", \
          "--prefix=#{prefix}", \
          "--disable-documentation", \
          build.stable? ? "--with-ncsb-dir=#{font_dir}" : "--with-texgyre-dir=#{font_dir}"
      system "make", "-j#{Etc.nprocessors + 1}"
      system "make", "install"
    end
  end

  test do
    File.write("test.ly", <<~EOS
      \\version "#{version}"

      \\relative c' {
        \\clef treble \\key c \\major \\time 4/4
        c d e f |
        g a b c |
        \\bar "|."
      }
    EOS
    )
    system "lilypond", "test.ly"
  end
end
