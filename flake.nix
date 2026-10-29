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
          "ros2bag"
	  "mujoco-ros2-control"
#          "ros2doctor"
        ];
	extraPyPackages = [
	  "hpp-python"
	  "crocoddyl"
	  "qtm"
	  "mujoco"
	  "viser"
	  "yourdfpy"
	];
	# Qualisys SDK, `import qtm` in demo07's scripts/qualisys.py. Not in
	# nixpkgs; PyPI's "qtm" 2.1.2 (marked DEPRECATED there, renamed qtm-rt/qtm_rt,
	# but the old name keeps the `qtm.connect` API the script uses). Pure-python
	# wheel, no dependencies.
	pyPackages.qtm =
	  { buildPythonPackage, fetchurl }:
	  buildPythonPackage {
	    pname = "qtm";
	    version = "2.1.2";
	    format = "wheel";
	    src = fetchurl {
	      url = "https://files.pythonhosted.org/packages/py3/q/qtm/qtm-2.1.2-py3-none-any.whl";
	      hash = "sha256-qS+N2qDzMc0lbi2f0QDHkKbS0lsrEUZ4fr0Xq0LhBek=";
	    };
	    pythonImportsCheck = [ "qtm" ];
	  };
	# nixpkgs' mujoco ships libsimulate.a built with slim LTO (real code in
	# .gnu.lto_* sections, .text empty), which mujoco_ros2_control's CMake
	# links "directly" -- the linker silently drops it, leaving
	# mujoco::PlatformUIAdapter/GlfwAdapter undefined in the .so. Point
	# MUJOCO_SIMULATE_DIR at the real simulate/*.cc sources so the CMake
	# fallback compiles them from source instead. That branch also calls
	# set_compiler_options() (-Werror), which the 0.0.3 sources don't survive
	# against mujoco 3.11's mjtSize=long -- drop it, as the direct-link
	# branch used to.
	rosOverrideAttrs.mujoco-ros2-control =
	  { pkgs-final, drv-prev, ... }:
	  {
	    postPatch = (drv-prev.postPatch or "") + ''
	      substituteInPlace CMakeLists.txt --replace-fail \
	          'set(MUJOCO_SIMULATE_DIR "''${MUJOCO_ROOT}/include/simulate")' \
	          'set(MUJOCO_SIMULATE_DIR "${pkgs-final.mujoco.src}/simulate")'
	      sed -i '/^  set_compiler_options()$/d' CMakeLists.txt
	    '';
	  };
      }
    );
}
