require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-truffle5");

const { subtask } = require("hardhat/config");
const {
  TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD,
} = require("hardhat/builtin-tasks/task-names");

subtask(TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD).setAction(
  async ({ solcVersion }, _hre, runSuper) => {
    if (solcVersion !== "0.7.0") {
      return runSuper();
    }

    const solc = require("solc");

    return {
      version: solcVersion,
      longVersion: solc.version(),
      compilerPath: require.resolve("solc/soljson.js"),
      isSolcJs: true,
    };
  }
);

/** @type {import("hardhat/config").HardhatUserConfig} */
const config = {
  solidity: {
    version: "0.7.0",
    settings: {
      optimizer: { enabled: true, runs: 200 }
    }
  },
  networks: {
    hardhat: {
      chainId: 5777,
      gas: 8000000
    },
    test: {
      url: "http://127.0.0.1:8545",
      gas: 8000000,
      chainId: 5777
    }
  },
  paths: {
    sources: "contracts",
    tests: "test",
    cache: "cache",
    artifacts: "artifacts"
  },
};

module.exports = config;


