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
	  "gz-ros2-control"
	  "odometry-gz-hw-interface"
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
	# gepetto/nix nulls out tensorflow-bin (tensorflow/tensorflow#102890).
	# With the nixpkgs bumped in by `nix flake update` (nix-ros-overlay's
	# nixpkgs 2026-09-28), that makes `tensorflow` itself null, and every
	# `tensorflow.meta.broken` check inside etils's own default.nix (its
	# disabledTestPaths list, its optional-dependencies.all) crashes on
	# `null.meta` as soon as anything forces etils's attrs (e.g. mujoco's
	# propagatedBuildInputs, pulled into the devShell). Feed etils a fake,
	# already-broken `tensorflow` constructor arg instead of a real one, so
	# every such check sees `broken = true` and skips the tensorflow-only
	# branch without ever touching the real (nulled) tensorflow. Still
	# present on gepetto/nix's origin/main as of this writing -- not yet
	# fixed upstream.
	pyOverrides.etils = {
	  tensorflow = {
	    meta.broken = true;
	  };
	};
	# gazebros2nix's todo.nix pins a `fetchpatch2` of gz-gui PR #696 by hash;
	# GitHub has since regenerated that PR's diff (rebase/force-push), so the
	# pinned hash no longer matches -- unrelated to VWBC, hit purely by
	# updating the flake. Re-point it at the hash the fetch actually
	# produces now.
	overlays = [
	  (
		final: prev: {
		  gazeboPackages = prev.gazeboPackages // {
			fortress = prev.gazeboPackages.fortress.overrideScope (
			  _fortress-final: fortress-prev: {
				ign-gui6 = fortress-prev.ign-gui6.overrideAttrs {
				  patches = [
					(final.fetchpatch2 {
					  url = "https://github.com/gazebosim/gz-gui/pull/696.patch?full_index=1";
					  hash = "sha256-NIk6UAViwK/qwPk4LiyByZkfDEuh7Tc9RdHyRXRjd4I=";
					})
				  ];
				};
			  }
			);
		  };
		}
	  )
	];
	# tiago_pro_gazebo depends on gz_ros2_control (the Gazebo<->ros2_control
	# bridge for the "gazebo"/Ignition sim backend), but nix-ros-overlay only
	# packages it for ros-jazzy, not humble/alum -- missing from this
	# workspace since Gazebo was never exercised here before (pal_gazebo_worlds
	# was excluded on purpose, see workspace.repos). Build it ourselves.
	# Tried upstream's `humble` branch first: it find_package()s the raw
	# ignition-gazebo6/ignition-plugin1 (matching our Fortress closure) but
	# calls hardware_interface APIs (bare `ResourceManager()`,
	# `HardwareInfo::hardware_class_type`, `ResourceManager::load_urdf`) that
	# don't exist in our hardware-interface 4.49.0 (pal-alum ABI patch,
	# tracking a much newer ros2_control than stock humble) -- real
	# incompatibility, not a flake/env issue. upstream's `rolling` branch
	# uses the current hardware_interface API instead, and depends on the
	# gz_sim_vendor/gz_plugin_vendor ROS wrappers (gz-sim-vendor/
	# gz-plugin-vendor) already in this closure -- use that branch instead.
	rosPackages.gz-ros2-control =
	  {
	    buildRosPackage,
	    fetchFromGitHub,
	    ament-cmake,
	    ament-index-cpp,
	    controller-manager,
	    hardware-interface,
	    pluginlib,
	    rclcpp,
	    rclcpp-lifecycle,
	    ros2-control-cmake,
	    yaml-cpp-vendor,
	    gz-sim-vendor,
	    gz-plugin-vendor,
	  }:
	  buildRosPackage {
	    pname = "ros-alum-gz-ros2-control";
	    version = "rolling";
	    src = fetchFromGitHub {
	      owner = "ros-controls";
	      repo = "gz_ros2_control";
	      rev = "7ed5f62def45e9dd879ad8969248e98bf0398b3f";
	      hash = "sha256-fU3QkpMx78JD/CR7RxhRRDnxaQVnezIof7zBQneNwIk=";
	    };
	    sourceRoot = "source/gz_ros2_control";
	    buildType = "ament_cmake";
	    nativeBuildInputs = [
	      ament-cmake
	      ros2-control-cmake
	    ];
	    propagatedBuildInputs = [
	      ament-index-cpp
	      controller-manager
	      hardware-interface
	      pluginlib
	      rclcpp
	      rclcpp-lifecycle
	      yaml-cpp-vendor
	      gz-sim-vendor
	      gz-plugin-vendor
	    ];
	  };
	# agimus_demos' tiago_pro.urdf.xacro's "ros2_control_odometry_system" block
	# (JointStateEstimator/linear_feedback_controller free-flyer support)
	# instantiates a custom hardware plugin,
	# odometry_gz_hw_interface/OdometryHardware, that doesn't exist anywhere
	# public -- it's our own small package, normally vcs-checked out, but
	# colcon-building it inside the devshell fails: its (transitive, via
	# gz_ros2_control's headers) gz-msgs10 include pulls in a NEWER protobuf's
	# generated .pb.h, while this devshell's merged "ros-env" prefix (every ROS
	# package's cmake config here points find_package() consumers at that same
	# merged include dir, not each package's own store path) also puts an
	# OLDER protobuf's headers on the search path, and the stale one wins --
	# same failure regardless of target_link_libraries order, since it's baked
	# into how find_package() resolves in this prefix, not an ordering bug.
	# gz-ros2-control above doesn't hit this because its real build happens in
	# a Nix derivation sandbox (precise per-dependency include paths, no
	# merged "ros-env"), not colcon-in-devshell -- so build this one the same
	# way instead of fighting the devshell. Source lives under
	# src/vcs_tiago_pro/odometry_gz_hw_interface (COLCON_IGNOREd so colcon
	# doesn't also try and fail), ported here from the original's
	# ignition-gazebo6-era API (ignition::gazebo::v6::EntityComponentManager,
	# int& level) to gz_ros2_control's current gz::sim-era
	# GazeboSimSystemInterface::initSim signature.
	rosPackages.odometry-gz-hw-interface =
	  {
	    buildRosPackage,
	    ament-cmake,
	    rclcpp,
	    nav-msgs,
	    pluginlib,
	    hardware-interface,
	    gz-ros2-control,
	    gz-sim-vendor,
	  }:
	  buildRosPackage {
	    pname = "ros-alum-odometry-gz-hw-interface";
	    version = "0.0.1";
	    src = ./src/vcs_tiago_pro/odometry_gz_hw_interface;
	    buildType = "ament_cmake";
	    nativeBuildInputs = [ ament-cmake ];
	    propagatedBuildInputs = [
	      rclcpp
	      nav-msgs
	      pluginlib
	      hardware-interface
	      gz-ros2-control
	      gz-sim-vendor
	    ];
	  };
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
