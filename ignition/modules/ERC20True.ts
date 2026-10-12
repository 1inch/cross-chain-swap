import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ERC20TrueModule", (m) => {
  const create3Deployer = m.getParameter("create3Deployer");
  const salt = m.getParameter("salt");
  const initCode = m.getParameter("initCode");

  const deployer = m.contractAt("ICreate3Deployer", create3Deployer);
  const deployCall = m.call(deployer, "deploy", [salt, initCode]);

  // addressOf(salt) is deterministic; `after` ties it to the deploy so the
  // returned ERC20True future is only used once the contract exists.
  const erc20TrueAddress = m.staticCall(deployer, "addressOf", [salt], 0, {
    after: [deployCall],
  });
  const erc20True = m.contractAt("ERC20True", erc20TrueAddress);

  return { erc20True };
});
