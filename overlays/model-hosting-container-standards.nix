final: prev:

let
  model-hosting-container-standards = prev.python3Packages.model-hosting-container-standards.overrideAttrs (oa: {
    disabledTests = (oa.disabledTests or []) ++ [
      "test_customer_script_functions_auto_loaded"
      "test_environment_variable_overrides_decorators"
      "test_customer_sets_environment_variables"
      "test_customer_writes_script_file"
      "test_customer_priority_understanding"
      "test_customer_decorator_usage_with_server_response"
      "test_register_handlers_priority_vs_script_functions"
      "test_framework_routes_are_created_automatically"
      "test_nested_jmespath_transformations"
    ];
  });
in

{
  python3Packages = prev.python3Packages // {
    inherit model-hosting-container-standards;
  };
}
