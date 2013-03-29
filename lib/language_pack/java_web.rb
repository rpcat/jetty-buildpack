require "language_pack/java"
require "language_pack/database_helpers"
require "fileutils"

# TODO logging
module LanguagePack
  class JavaWeb < Java
    include LanguagePack::PackageFetcher
    include LanguagePack::DatabaseHelpers

    JETTY_VERSION = "9.0.0.v20130308".freeze
    JETTY_PACKAGE =  "jetty-distribution-#{JETTY_VERSION}.tar.gz".freeze
    WEBAPP_DIR = "webapps/ROOT/".freeze

    def self.use?
      File.exists?("WEB-INF/web.xml") || File.exists?("webapps/ROOT/WEB-INF/web.xml")
    end

    def name
      "Java Web"
    end

    def compile
      Dir.chdir(build_path) do
        install_java
        install_jetty
        remove_jetty_files
        copy_webapp_to_jetty
        move_jetty_to_root
        install_database_drivers
        #install_insight
        copy_resources
        setup_profiled
      end
    end

    def install_jetty
      FileUtils.mkdir_p jetty_dir
      jetty_tarball="#{jetty_dir}/jetty-distribution-#{JETTY_VERSION}.tar.gz"

      download_jetty jetty_tarball

      puts "Unpacking Jetty to #{jetty_dir}"
      run_with_err_output("tar xzf #{jetty_tarball} -C #{jetty_dir} && mv #{jetty_dir}/jetty-distribution*/* #{jetty_dir} && " +
              "rm -rf #{jetty_dir}/jetty-distribution*")
      FileUtils.rm_rf jetty_tarball
      unless File.exists?("#{jetty_dir}/bin/jetty.sh")
        puts "Unable to retrieve Jetty"
        exit 1
      end
    end

    def download_jetty(jetty_tarball)
      puts "Downloading Jetty: #{JETTY_PACKAGE}"
      fetch_package JETTY_PACKAGE, "http://repo2.maven.org/maven2/org/eclipse/jetty/jetty-distribution/#{JETTY_VERSION}/"
      FileUtils.mv JETTY_PACKAGE, jetty_tarball
    end

    def remove_jetty_files
# TODO
#      %w[NOTICE RELEASE-NOTES RUNNING.txt LICENSE temp/. webapps/. work/. logs].each do |file|
#        FileUtils.rm_rf("#{jetty_dir}/#{file}")
#      end
    end

    def jetty_dir
      ".jetty"
    end

    def copy_webapp_to_jetty
      run_with_err_output("mkdir -p #{jetty_dir}/webapps/ROOT && mv * #{jetty_dir}/webapps/ROOT")
    end

    def move_jetty_to_root
      run_with_err_output("mv #{jetty_dir}/* . && rm -rf #{jetty_dir}")
    end

    def copy_resources
      # copy jetty configuration updates into place
      run_with_err_output("cp -r #{File.expand_path('../../../resources/jetty', __FILE__)}/* #{build_path}")
    end

    def java_opts
      # TODO proxy settings?
      opts = super.merge({ "-Djetty.port=" => "$VCAP_APP_PORT" })
      opts.delete("-Djava.io.tmpdir=")
      opts
    end

    def default_process_types
      {
        "web" => "./bin/jetty.sh run"
      }
    end

    def webapp_path
      File.join(build_path,"webapps","ROOT")
    end
  end
end