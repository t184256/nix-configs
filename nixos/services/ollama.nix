_:

{
  services.ollama = {
    enable = true;
    openFirewall = true;
    host = "192.168.99.7";
    environmentVariables = {
      #OLLAMA_CONTEXT_LENGTH = "131072";
      OLLAMA_CONTEXT_LENGTH = "32768";
      OLLAMA_LOAD_TIMEOUT = "20m";
      OLLAMA_KEEP_ALIVE = "20m";
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_INTEL_GPU = "true";
    };
    loadModels = [
    ];
  };
  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/private"; mode = "0700"; }
    {
      directory = "/var/lib/private/ollama";
      user = "ollama"; group = "ollama";
    }
  ];
}
