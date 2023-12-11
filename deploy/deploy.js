const hre = require('hardhat');
const { getChainId, ethers } = hre;

module.exports = async ({ deployments, getNamedAccounts }) => {
    const networkName = hre.network.name;
    console.log(`running ${networkName} deploy script`);
    const chainId = await getChainId();
    console.log('network id ', chainId);
    if (chainId !== hre.config.networks[networkName].chainId.toString()) {
        console.log(`network chain id: ${hre.config.networks[networkName].chainId}, your chain id ${chainId}`);
        console.log('skipping wrong chain id deployment');
        return;
    }

    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const constructorArgs = [];
    const contractName = 'Example';
    const deploymentName = 'ExampleDeployment';
    const exampleDeployment = await deploy(deploymentName, {
        args: constructorArgs,
        from: deployer,
        contract: contractName,
        skipIfAlreadyDeployed: true,
    });

    console.log(`${deploymentName} deployed to: ${exampleDeployment.address}`);

    if (chainId !== '31337') {
        await hre.run('verify:verify', {
            address: exampleDeployment.address,
            constructorArguments: constructorArgs,
        });
    }

    const Example = await ethers.getContractFactory('Example');
    const example = Example.attach(exampleDeployment.address);

    const txn = await example.func('1234');
    await txn;
};

module.exports.skip = async () => true;
