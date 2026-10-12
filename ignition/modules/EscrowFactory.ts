import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("EscrowFactoryModule", (m) => {
  const create3Deployer = m.getParameter("create3Deployer");
  const salt = m.getParameter("salt");
  const initCode = m.getParameter("initCode");

  const deployer = m.contractAt("ICreate3Deployer", create3Deployer);
  const deployCall = m.call(deployer, "deploy", [salt, initCode]);

  // addressOf(salt) is deterministic; `after` ties it to the deploy so the
  // returned EscrowFactory future is only used once the contract exists.
  const escrowFactoryAddress = m.staticCall(deployer, "addressOf", [salt], 0, {
    after: [deployCall],
  });
  const escrowFactory = m.contractAt("EscrowFactory", escrowFactoryAddress);

  return { escrowFactory };
});
