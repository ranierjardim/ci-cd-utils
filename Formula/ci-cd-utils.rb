class CiCdUtils < Formula
  desc "Some utils to manage CI/CD projects builds"
  homepage "https://github.com/ranierjardim/ci_cd_utils"
  url "https://github.com/ranierjardim/ci_cd_utils.git", :using => :git, :tag => "0.0.11-docker"
  license "MIT License"
  depends_on "cmake" => :build
  depends_on "dart-lang/dart/dart@2.19" => :build

  def install
    Dir.chdir("src/ci-cd-cmd-utils") do
        system "dart", "pub", "get"
        system "dart", "compile", "exe", "bin/ci_cd_cmd_utils.dart", "-o", "ci_cd_cmd_utils"
    end

    # Copiar o arquivo desejado para o diretório libexec
    libexec.install "src/ci-cd-cmd-utils/ci_cd_cmd_utils"

    # Dar permissão de execução para o arquivo
    (libexec/"ci_cd_cmd_utils").chmod 0755

    # Criar um arquivo de wrapper em torno do arquivo de script Dart
    (bin/"ci-cd-utils").write <<~EOS
        #!/bin/sh
        exec "#{libexec}/ci_cd_cmd_utils" "$@"
    EOS

    # Dar permissão de execução para o arquivo de wrapper
    (bin/"ci-cd-utils").chmod 0755
  end

end
