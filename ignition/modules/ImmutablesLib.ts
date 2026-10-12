import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ImmutablesLibModule", (m) => {
  const immutablesLib = m.library("ImmutablesLib");

  return { immutablesLib };
});
