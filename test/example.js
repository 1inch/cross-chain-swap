const hre = require('hardhat');
const { ethers } = hre;
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');

describe('Example', async function () {
    async function initContracts () {
        const Example = await ethers.getContractFactory('Example');
        const contract = await Example.deploy();
        await contract.waitForDeployment();
        return { contract };
    }

    it('should be ok', async function () {
        const { contract } = await loadFixture(initContracts);
        await expect(contract.func(1)).to.emit(contract, 'Log').withArgs(1);
    });

    it('should be skipped in coverage', async function () {
        if (hre.__SOLIDITY_COVERAGE_RUNNING) { this.skip(); }
        // TODO: add test
    });
});
