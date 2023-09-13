_: super:
rec {
  python3 = super.python3.override {
    packageOverrides = _: super: {
      python-lsp-server = super.python-lsp-server.overridePythonAttrs (oa: {
        disabledTests = oa.disabledTests ++ [
          "test_notebook_document__did_open"
          "test_notebook_document__did_change"
        ];
      });
    };
  };
  python3Packages = python3.pkgs;
  inherit (python3.pkgs) python-lsp-server;
}
