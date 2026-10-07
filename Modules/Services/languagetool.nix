{ inputs, ... }: {
  # LanguageTool at https://lt.ironshark.org, for VSCodium (LTeX+), the
  # Obsidian plugin and the Brave extension. English gets the n-gram data
  # (confusion pairs like their/there); Mandarin (zh-CN) uses the rules that
  # ship in the package, so it needs no extra data. fastText picks the
  # language when a client sends `auto`.
  #
  # The data (~9 GB zip, ~14 GB unpacked) is fetched once into /srv by
  # languagetool-data. That takes a while, so the deploy doesn't wait for
  # it: the server starts as soon as the data is in place.
  flake.nixosModules.Tn-languagetool = { config, lib, pkgs, ... }:
  let
    dir    = "/srv/languagetool";
    ready  = "${dir}/.ready";
    ngrams = "https://languagetool.org/download/ngram-data/ngrams-en-20150817.zip";
    lid    = "https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin";
    port   = 8081;
  in {
    services.languagetool = {
      enable = true;
      inherit port;
      allowOrigin = "*";   # browser extensions call it directly; tailnet-only anyway
      jvmOptions  = [ "-Xms512m" "-Xmx3g" ];
      settings = {
        cacheSize      = 5000;
        languageModel  = "${dir}/ngrams";   # holds en/
        fasttextModel  = "${dir}/lid.176.bin";
        fasttextBinary = lib.getExe' pkgs.fasttext "fasttext";
      };
    };
    systemd.services.languagetool.unitConfig.ConditionPathExists = ready;

    systemd.services.languagetool-data = {
      description = "Fetch LanguageTool's n-gram and fastText data";
      after    = [ "network-online.target" "zfs-mount.service" ];
      wants    = [ "network-online.target" ];
      requires = [ "zfs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ curl unzip coreutils systemd ];
      # Type=exec: the switch carries on while the download runs
      serviceConfig = {
        Type            = "exec";
        RemainAfterExit = true;
        Restart         = "on-failure";
        RestartSec      = "5min";
        Nice            = 10;
      };
      script = ''
        [ -e ${ready} ] && exit 0
        install -d -m 0755 ${dir}
        cd ${dir}
        # -C -: a failed run resumes where it stopped
        curl -fsSL --retry 5 -C - -o lid.176.bin.part ${lid}
        mv lid.176.bin.part lid.176.bin
        curl -fsSL --retry 5 -C - -o ngrams.zip.part ${ngrams}
        rm -rf ngrams.tmp
        unzip -q ngrams.zip.part -d ngrams.tmp
        rm -rf ngrams && mv ngrams.tmp ngrams && rm ngrams.zip.part
        chmod -R a+rX ${dir}
        touch ${ready}
        systemctl start --no-block languagetool.service
      '';
    };

    tn.web.vhosts.lt = { inherit port; maxBody = "10m"; };
  };
}
