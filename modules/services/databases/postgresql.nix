{pkgs, config, ...}:

###### interface
let
  inherit (pkgs.lib) mkOption mkIf;

  options = {
    services = {
      postgresql = {
        enable = mkOption {
          default = false;
          description = "
            Whether to run PostgreSQL.
          ";
        };
        port = mkOption {
          default = "5432";
          description = "
            Port for PostgreSQL.
          ";
        };
        logDir = mkOption {
          default = "/var/log/postgresql";
          description = "
            Log directory for PostgreSQL.
          ";
        };
        dataDir = mkOption {
          default = "/var/db/postgresql";
          description = "
            Data directory for PostgreSQL.
          ";
        };
        subServices = mkOption {
          default = [];
          description = "
            Subservices list. As it is already implememnted, 
            here is an interface...
          ";
        };
        authentication = mkOption {
          default = ''
            # Generated file; do not edit!
            local all all              ident sameuser
            host  all all 127.0.0.1/32 md5
            host  all all ::1/128      md5
          '';
          description = "
            Hosts (except localhost), who you allow to connect.
          ";
        };
        allowedHosts = mkOption {
          default = [];
          description = "
            Hosts (except localhost), who you allow to connect.
          ";
        };
        authMethod = mkOption {
          default = " ident sameuser ";
          description = "
            How to authorize users. 
            Note: ident needs absolute trust to all allowed client hosts.";
        };
        enableTCPIP = mkOption {
          default = false;
          description = "
            Whether to run PostgreSQL with -i flag to enable TCP/IP connections.
          ";
        };
      };
    };
  };
in

###### implementation

let

  cfg = config.services.postgresql;

  postgresql = pkgs.postgresql;

  startDependency = if config.services.gw6c.enable then 
    "gw6c" else "network-interfaces";

  run = "${pkgs.su}/bin/su -s ${pkgs.bash}/bin/sh postgres";

  flags = if cfg.enableTCPIP then ["-i"] else [];

in

mkIf config.services.postgresql.enable {
  require = [
    options
  ];


  users = {
    extraUsers = [
      { name = "postgres";
        description = "PostgreSQL server user";
      }
    ];

    extraGroups = [
      { name = "postgres"; }
    ];
  };

  services = {
    extraJobs = [{
      name = "postgresql";

      extraPath = [postgresql];

      job = ''
        description "PostgreSQL server"

        start on ${startDependency}/started
        stop on shutdown
        
        start script
            if ! test -e ${cfg.dataDir}; then
                mkdir -m 0700 -p ${cfg.dataDir}
                chown -R postgres ${cfg.dataDir}
                ${run} -c '${postgresql}/bin/initdb -D ${cfg.dataDir} -U root'
            fi
            cp -f ${pkgs.writeText "pg_hba.conf" cfg.authentication} ${cfg.dataDir}/pg_hba.conf
        end script

        respawn ${run} -c '${postgresql}/bin/postgres -D ${cfg.dataDir} ${toString flags}'
      '';
      }];
  };
}