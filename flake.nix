{
  inputs.nix.url = "github:gepetto/nix";

  outputs =
    inputs:
    inputs.nix.lib.mkFlakoboros inputs (
      { lib, ... }:
      (lib.importJSON ./wsconf.json)
      // {
        extraRosPackages = [
          "launch-testing-ament-cmake"
          "ament-cmake-cppcheck"
          "ament-cmake-cpplint"
          "ament-cmake-uncrustify"
          "ament-cmake-flake8"
          "ament-cmake-pep257"
          "ament-lint-cmake"
          "ament-xmllint"
          "rmw-cyclonedds-cpp"
        ];
	extraPyPackages = [
	  "hpp-python"
	];
      }
    );
}
