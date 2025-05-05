// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@limitbreak/tokenmaster/src/DataTypes.sol";
import "@limitbreak/tokenmaster/src/interfaces/ITokenMasterRouter.sol";
import "@limitbreak/tokenmaster/src/interfaces/ITokenMasterFactory.sol";
import "@limitbreak/tm-core-lib/src/token/erc20/IERC20.sol";
import "@limitbreak/tokenmaster/src/pools/standard-token-pool/DataTypes.sol";

interface IRouterView {
    function infrastructureFeeBPS() external view returns (uint16);
}

contract DeployStandardPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address routerAddr = 0x0E00009d00d1000069ed00A908e00081F5006008;
        address tokenFactory = 0x0000008fA9E16d40F879402FB580bAc7bdFA7d7e;
        address initialOwner = vm.addr(deployerPrivateKey);
        address pairedToken = 0xA959726154953bAe111746E265E6d754F48570E6; //WRON

        uint256 initialDeposit = 1 ether;

        StandardPoolInitializationParameters memory initParams = StandardPoolInitializationParameters({
            minBuySpreadBPS: 100,
            maxBuySpreadBPS: 500,
            maxBuyFeeBPS: 200,
            maxBuyDemandFeeBPS: 150,
            minSellSpreadBPS: 100,
            maxSellSpreadBPS: 500,
            maxSellFeeBPS: 200,
            maxSpendCreatorShareBPS: 1000,
            creatorEmissionRateNumerator: 1e18,
            creatorEmissionRateDenominator: 31536000,
            creatorEmissionsHardCap: 100000e18,
            initialSupplyRecipient: initialOwner,
            initialSupplyAmount: 1_000_000e18,
            initialBuyParameters: StandardPoolBuyParameters({
                    buySpreadBPS: 100,
                    buyFeeBPS: 50,
                    buyCostPairedTokenNumerator: 1,
                    buyCostPoolTokenDenominator: 100,
                    useTargetSupply: false,
                    reserved: 0, 
                    buyDemandFeeBPS: 0,
                    targetSupplyBaseline: 0,
                    targetSupplyBaselineScaleFactor: 0,
                    targetSupplyGrowthRatePerSecond: 0,
                    targetSupplyBaselineTimestamp: 0
            }),
            initialSellParameters: StandardPoolSellParameters({
                sellSpreadBPS: 200,
                sellFeeBPS: 100
            }),
            initialSpendParameters: StandardPoolSpendParameters({
                creatorShareBPS: 500
            }),
            initialPausedState: 0
        });

        bytes memory encodedArgs = abi.encode(initParams);

        PoolDeploymentParameters memory poolParams = PoolDeploymentParameters({
            name: "MyToken",
            symbol: "MTK",
            tokenDecimals: 18,
            initialOwner: initialOwner,
            pairedToken: pairedToken,
            initialPairedTokenToDeposit: initialDeposit,
            encodedInitializationArgs: encodedArgs,
            defaultTransferValidator: address(0),
            useRouterForPairedTransfers: false,
            partnerFeeRecipient: address(0),
            partnerFeeBPS: 0
        });

        bytes32 salt = keccak256(abi.encodePacked("test-salt"));
        uint256 infraFee = IRouterView(routerAddr).infrastructureFeeBPS();
        address expectedTokenAddress = ITokenMasterFactory(tokenFactory).computeDeploymentAddress(
            salt,
            poolParams,
            initialDeposit,
            infraFee
        );

        IERC20(pairedToken).approve(routerAddr, initialDeposit);

        DeploymentParameters memory params = DeploymentParameters({
            tokenFactory: tokenFactory,
            tokenSalt: salt,
            tokenAddress: expectedTokenAddress,
            blockTransactionsFromUntrustedChannels: false,
            restrictPairingToLists: false,
            poolParams: poolParams,
            maxInfrastructureFeeBPS: 500
        });

        SignatureECDSA memory sig = SignatureECDSA({
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        ITokenMasterRouter(routerAddr).deployToken(params, sig);

        console.log("Deployed token at:", expectedTokenAddress);

        vm.stopBroadcast();
    }
}
