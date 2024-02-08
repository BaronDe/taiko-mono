// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";
import "./AccountProofVerification_old/LibTrieProof_old.sol";
import "../../contracts/libs/LibTrieProof.sol";

contract TestSignalService is TaikoTest {
    AddressManager addressManager;
    SignalService relayer;
    SignalService destSignalService;
    DummyCrossChainSync crossChainSync;
    uint64 public destChainId = 7;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);

        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, ()),
                registerTo: address(addressManager),
                owner: address(0)
            })
        );

        relayer = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, ())
            })
        );

        destSignalService = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, ())
            })
        );

        crossChainSync = DummyCrossChainSync(
            deployProxy({
                name: "dummy_cross_chain_sync",
                impl: address(new DummyCrossChainSync()),
                data: ""
            })
        );

        register(address(addressManager), "signal_service", address(destSignalService), destChainId);

        register(address(addressManager), "taiko", address(crossChainSync), destChainId);

        vm.stopPrank();
    }

    function test_SignalService_sendSignal_revert() public {
        vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
        relayer.sendSignal(0);
    }

    function test_SignalService_isSignalSent_revert() public {
        bytes32 signal = bytes32(uint256(1));
        vm.expectRevert(SignalService.SS_INVALID_APP.selector);
        relayer.isSignalSent(address(0), signal);

        signal = bytes32(uint256(0));
        vm.expectRevert(SignalService.SS_INVALID_SIGNAL.selector);
        relayer.isSignalSent(Alice, signal);
    }

    function test_SignalService_sendSignal_isSignalSent() public {
        vm.startPrank(Alice);
        bytes32 signal = bytes32(uint256(1));
        relayer.sendSignal(signal);

        assertTrue(relayer.isSignalSent(Alice, signal));
    }

    function test_SignalService_getSignalSlot() public {
        vm.startPrank(Alice);
        for (uint8 i = 1; i < 100; ++i) {
            bytes32 signal = bytes32(block.prevrandao + i);
            relayer.sendSignal(signal);

            assertTrue(relayer.isSignalSent(Alice, signal));
        }
    }

    // function test_SignalService_proveSignalReceived_L1_L2() public {
    //     uint64 chainId = 11_155_111; // Created the proofs on a deployed Sepolia
    //         // contract, this is why this chainId.
    //     address app = 0x927a146e18294efb36edCacC99D9aCEA6aB16b95; // Mock app,
    //         // actually it is an EOA, but it is ok for tests!
    //     bytes32 signal = 0x21761f7cd1af3972774272b39a0f4602dbcd418325cddb14e156b4bb073d52a8;
    //     bytes[] memory inclusionProof = new bytes[](1);

    //     inclusionProof[0] =
    //         hex"e3a1209749684f52b5c0717a7ca78127fb56043d637d81763c04e9d30ba4d4746d56e901";

    //     bytes32 stateRoot = 0xf7916f389ccda56e3831e115238b7389b30750886785a3c21265601572698f0f;

    //     vm.startPrank(Alice);
    //     relayer.authorize(address(crossChainSync), bytes32(uint256(block.chainid)));

    //     crossChainSync.setSyncedData("", stateRoot);

    //     SignalService.Proof memory p;
    //     SignalService.Hop[] memory h;
    //     p.crossChainSync = address(crossChainSync);
    //     p.height = 10;
    //     p.merkleProof = inclusionProof;
    //     p.hops = h;

    //     bool isSignalReceived = relayer.proveSignalReceived(chainId, app, signal, abi.encode(p));
    //     assertEq(isSignalReceived, true);
    // }

    function test_account_proof_new() public {
        uint64 chainId = 11_155_111; // Created the proofs on a deployed Sepolia
            // contract, this is why this chainId.
        // Actually this is the messageHash i sent (obviously just a made up bytes32!)
        bytes32 signalSent = 0x21761f7cd1af3972774272b39a0f4602dbcd418325cddb14e156b4bb073d52a8; //Actually a messageHash
        // This one is the "sender app" aka the source bridge but i mocked it for now to be an EOA (for slot calculation)
        address contractWhichStoresValue1AtSlot = 0x17DF3c450D1dC61558ecA7B10e4bBC8ddcdB1f28;
        // This is the slot i queried the eth_getProof on Sepolia for blockheight: 0x5000B5
        bytes32 slotStoredAtTheApp = 0xfa2ef1bab164a0522c2c110bbea1a54ac6399d3ba24437480c29947143a5402e;
        // This is the worldStateRoot at blockheight: 0x5000B5
        bytes32 worldStateRoot = 0x90c5f343ed98545ad5ad4e840492e1008218c0ea92f8fd74a826aaf4c477a3fe;
        // This is the worldStateRoot just RLP encoded with https://toolkit.abdk.consulting/ethereum#key-to-address,rlp
        // I know this online tooling works because used it multiple times with MessageService showcase app with out bridge demonstaration and workshops
        bytes memory worldStateRootRLPEncoded = hex"e1a090c5f343ed98545ad5ad4e840492e1008218c0ea92f8fd74a826aaf4c477a3fe";

        bytes[] memory accountProof = new bytes[](8);
        // eth_getProof responds some bytes
        accountProof[0] = hex"f90211a01564179a33d2ff80c3618ab74314aad556cb7652c2d51f7a3aff3a787ecdb29ea03bd6509773c4530091e420ef4921beef2be63ad2429b6e12ba5d7a7f9a6da270a090be43dc028d9eb13a63b5799782f30928e6882b328ab845f320e1eb138d7962a026633ae06c23cd30c5e1cc91cfd7be03652cb9c853fa42538803c8eb631e920fa0711616cf812d7ed5f308b2822bffc5038edac8abedb0f7339c9933387472b495a09266ec8cec3b85e1ea194e79c73a4b2ecc122abffa356b575c31af7e9d3b6921a0a16f884fe19eeaefb8eeb2f017f6ecb24ee5822d5b3bc4be98bcfe374a910761a07973653d008e00cebcc3794f8221fa530d9a18ce77331a3e473e8dc3735943d9a0bc31a4cd1ab5c4ff0bd12f6ffc12f5ef19897df9addc478aa06b223d3087ef9da059aec5d8753109a5893d67ec742b2b51703ecf5920e4947007a6c77265ac41f9a09c0af28e7444278ab0b478870fa98c9f37e9d19681023f8e039f3ce67492e707a008395a6c64c1c76a1e655a28419504519e9957251e83501eef6093971f937c19a04f2a4e14fe7bbf05ea2b75de2bfe95fd33d2c86ff554293ebdf09da7da579cd5a0816ed8d0b69fce577f3c70eceebe8634387716d91a1edc4b3cc9d5feea31ba94a0a270d82ecded0d0712336be6e078794e533721b40698c9b5165b6c420a8a8545a0bcfbc71cc6ee796c58ef28f0d0e453fc08f6326c1891b51512e19af5f4842ffe80";
        accountProof[1] = hex"f90211a0c441ffc1fe3662f328ca995e9cad90cecf26ad98028846b7a1bdb6fe60aa8419a058336ba27c2e0feb5bd8bdeea62ebe54fc4cc05e2376f69e1c721b1cd9098498a07b847e55c107bd976b5984ea7d97d39c68573ae74afd82d4ab9d857cb44e6f82a05f5c1810a0178191798266d171f2f9f9711f5116c5dc4ecccbc29642a24b1873a01da99f321b183e1a2068ac0fd57dccbd637b3fa91b060a80c836ce1ea79fcae0a0f8cf0f8299146bf9d1ec0b8932ddc23ec29cd61daf5cdbe704a5c90f31f0d60ca0407441445132919ff986f169f24e82ce53fe15a444a674ab1604f0924efdd51da0313be5d2f630a30f414aed4012bbe081e55853a55209a3a83045b62f10d74ad2a0ab4a1665cc9ac1dc2f87d98c55e9b893acf84e592635d359a83d0e14181a933da0e4ed4ac12b93b12016ae1c0fd62e6a15b01e617779e8611c27ce22b0b5e78d68a0852127e581d41ec5c58d6a5ccb1b0e7ae90553575b0d9ffb2ac847515671c80fa01ec12bc1938419bebfdc17ed6d10d456fe31202f2dd1534e9bc6b78c95e2b358a000e5a67fdc3cc307a3244b77ddb504867a2cfb0cc9a614a47452d8cfad011af4a0a222a375f0b35461137d84e1beb8cc0e842ea7194784286b0426d80e04ce0ee6a04dc890b4343e041888128a5185860e039b82636d328c52f630007339d445fc0aa00619a2c3c30245bef0821c9f85bc3b79ee2b7f895a4de79ad57f42add8f8cc8d80";
        accountProof[2] = hex"f90211a02b8838e8f55f133d202a53a8b8d9243d936f43b636e8edf4cead5028150ba4bda0199e1c6b8025bdb25824acf47c79f2cb46e9912eea4c7951b1841e6831361cf7a03f9cf217c04256b4b8d32218e998e34a2bb16c17aec758811d9cf2b2510a50a0a06a04facdefe440e0d78718bee9ac31d6693d197ea44bb324156d3bcbdc601763a0d30849e23529944c1763e9de2d3ae6d229b4310bcb2415dec58e5375d04d23efa0a4013ee6afb6af932f3e2d126fbe53f656be59f27df7c700099c91e2a65e2bd3a0233ef3fbc0234cbcb9f76ad4ece6c2f50e480e873226f8f8cef2851d10a7ee33a0b5d1dc30ea1bad8ac548ffd9ac408eabb033f2fcf8d3c1780da97180d89f5997a0a4192803a6131538e307b331f9f842b2302d17492f37537a56a63c36eb01b408a06087dc2726b6a21a4d06d7d73b988925cf3ba2c898d442024468a52f8a4010a8a0bfa291361ed2810c2f8ab0eee7fd894e5915e8ad2d12739d4f380466dc3c7f55a08becd8c73f80d6073df6cceb89e796e669744aa852ce13c7b367fe60c2b34d04a012c2d1a15f1bf98ad00cd0eb061a42eaaf0015a5f4c41a894f249c9a3afc3560a0fef566b4ad9fa37ee9ae59f880f4bb38958c8a62f26ae3668f1dbda3e9fd3b05a0702301629db7bdddcc00dbd348adbcffc890bb1c80fe6ef7a996363adc89770da068b975b9b36fc59378c54d5dd868e53ea8a59248da1dc6c4576d9f781913cd7880";
        accountProof[3] = hex"f90211a0d98672296e62b8aba7e20671ca0476e58efc4ad0c40480e9ced84696bbfa56a8a0d2c53384b6e3b1b3088fcd412af98f85a52b882914a35adb2aa56cd3484997ada09015daa671fe301f656b0ed4f4f2172d683dae40113979a3f710145106031767a00d055b96c4f5804b7d3e4b8159d72bd84ca9e8b4547b504fe2a9933b4359a2d4a0d2560c909a3b2cc465480d1815b06c613d7a2ae7f6c1f00027cf4a57cdc282d7a0c29b7764bdd0df90b1fe350b488ffe69c3c4202f1712c77aab4fa2e0103ae673a06ca16b3f2b111bb14b8b52d36b85b7df2dada9796c2dd0b13f293149cb3e38fba0219ab02566d6474fa0621669616f97f7be79e1cb5886bc75be99be4984bd978ca0d103757173ada974a0f4996e3191ebce8f3ddc61c9db536ff7389c010b03e536a0f65268a6de255bde8ea97282e9f7a858b15b5bde5b9cde5b654c19cd909231f8a06c3ee37ad1762f6fb9da2b3efec779a61036f76b4c97b3ba8ea1339cfc76393ea09b28c2f98e0eedafa97d733d468c1d7a505f8d6b544bbbaf990cdd4781ee765ea0eeda6a2e3dd383ab103d9c14656df77a6b05a566338745325edb03ab344c7404a0ca35c2b85039e6a1fce323649d015876c13702faa510cee4f4a7efaac5456185a00a0e83158f3c174485b6b6ff64f793d0bd578215a685acc86b002bcc99c99f9ba0fd0d0c3d0f27d3e7bc63462df509157e56d03e310ee26a60a4f7dfa87a9e0c2080";
        accountProof[4] = hex"f90211a0f69c09b524b3e7a97fe238809583b7b68f41443a76c0f5d689b371c1df513fc1a0d0f0bcbbd6dae7bd8dd9ba196a34e81c7cc9fea6ac4894a69ec2b5b7bdae2f01a081975fbe995c9a7a55b8e846a70be0d6695c8529b7f564448bf64f2ef25d8c5ca02cd43f9e6fafbe13cc8e845d8c19b51ddc62610119948c635c7e1c9c9998dc22a03b4e6dfe0edcdfbb0b8252f97cc6d2a11f25c571b093cc53aca88d38a94bf827a0e9b70cbde13f142578dba52a5a862122a2332e15c148edda2b9b419528ee9231a014ff7fc46869c016d4ac3b0487a59bf269a4d80fd1afce355f5343d8135bcadaa0d65fafd2a1e02154fcf48c51a354ab294799c6c0444bfadc792ea195e9b9fdefa0edfde20b547f393f4c05f1e6e32b10da328df10d0b231b5c5af4f0d02bdd3492a095fd7a02b5be79308c127233cec06c203ae54ed2c85b69878eeb13abfc9d6a9aa0af6751551d96ea25ae9afb6113a2c13bef56254c3ea24b1a643562fdbdb4100da0c3b3d7526009039e7cf06279d8226f536ccedbed96da7d3f82aa878063bbeb9aa03dcfed22cae1cee772be285fbba92960fe887eb0997eb9a221849e690b2a6917a05c86e58c113f61d4c44bbe0d6c45ee4d4cdf1ecf308d1f0d43f2a284e0bd1300a03eea9d225bd25dc3dc2d48bf156abc17e6d20686624fa5e93ab8b05f42058e34a0794f702cf0ca4e67ad88a9e9ee7d51adf3b3b3aa47621aa5bf0b8cab433176ec80";
        accountProof[5] = hex"f901f1a0605770c9b68c1b4e33579a35850c1c44731852d55172ec379b2377e54c359d9ca0d704783a3e1d333129d0305964be5f1af602b860253deddb80c0b36bb71f697ca0b4c43f62e620af02dbeaf9d0e79b62d30041ef97ceb70190e3a1bfa0711ddd21a0ffc993b4e33b8a39b84563804f7439299ca8cc0ce747625fb160baccaac0ae56a073146beddea840ed57473fa066835ba3f5b4a7a950965aa8b97b55604ad328e280a0461d8ad7f395cfca01b2b5173ac2cbc81f0343061a4cad2d93593b29d91ba9baa067a777686549c4b2408aa78e935a777bc447b5055a778faf62a5dda63f5c274ea0903c36605f0616a74dcbb4730437ffefea698cbef452e19a08072830f25c581fa06ff86e3168eb6b77472acb077d925fd36000139a924531125a1cd469152712d2a048fd7f01074966c50c0a3cc68a53a0ea29410c0f9a37595657493ec9dffcd4e9a02358f5f4c8b91b0b865a8f70f22f9f082aefeccd53776ba835ead842ff9d74a0a03f7d16b8024d3f8cd006b4e6cc69ce07c520178254ebafe68ada722871342257a08e1bf934b22c0a817fb470fb0e8c792fd1987f062a1af318de783df5a9c71081a063d0b5247f4a977839a12223db8c2e6f120ea6f0db673f0fb056415745e8015ba0cca532f0172104741733687ad1b87337f554def14726f29fabc556b070d077cf80";
        accountProof[6] = hex"f8518080808080808080808080a04fc082a60fe2f12e75c8d6dddca59133c0e855e7d412ffbaba8c2117d37aa35780a06bd1536769280b725a364161ed10f1737f8b70938227ae1cdda228f45ac1e168808080";
        accountProof[7] = hex"f8669d3a74f1d0cadee872fd4b113921a69b6f137711ffc6bc55289ddac192dcb846f8440180a0f7916f389ccda56e3831e115238b7389b30750886785a3c21265601572698f0fa040ed175bbf1e21348615151831ea7a1164fb6d1bd4e1fa03290f0d97bd122021";

        bytes[] memory storageProof = new bytes[](1);
        storageProof[0] = hex"e3a1209749684f52b5c0717a7ca78127fb56043d637d81763c04e9d30ba4d4746d56e901";
        bytes memory merkleProof = abi.encode(accountProof, storageProof);

        vm.startPrank(Alice);
        LibTrieProof.verifyWithAccountProof(worldStateRoot, contractWhichStoresValue1AtSlot, slotStoredAtTheApp, hex"01", merkleProof);
    }


    function test_account_proof_old() public {
        uint64 chainId = 11_155_111; // Created the proofs on a deployed Sepolia
            // contract, this is why this chainId.
        // Actually this is the messageHash i sent (obviously just a made up bytes32!)
        bytes32 signalSent = 0x21761f7cd1af3972774272b39a0f4602dbcd418325cddb14e156b4bb073d52a8; //Actually a messageHash
        // This one is the "sender app" aka the source bridge but i mocked it for now to be an EOA (for slot calculation)
        address contractWhichStoresValue1AtSlot = 0x17DF3c450D1dC61558ecA7B10e4bBC8ddcdB1f28;
        // This is the slot i queried the eth_getProof on Sepolia for blockheight: 0x5000B5
        bytes32 slotStoredAtTheApp = 0xfa2ef1bab164a0522c2c110bbea1a54ac6399d3ba24437480c29947143a5402e;
        // This is the worldStateRoot at blockheight: 0x5000B5
        bytes32 worldStateRoot = 0x90c5f343ed98545ad5ad4e840492e1008218c0ea92f8fd74a826aaf4c477a3fe;
        // This is the worldStateRoot just RLP encoded with https://toolkit.abdk.consulting/ethereum#key-to-address,rlp
        // I know this online tooling works because used it multiple times with MessageService showcase app with out bridge demonstaration and workshops
        bytes memory worldStateRootRLPEncoded = hex"e1a090c5f343ed98545ad5ad4e840492e1008218c0ea92f8fd74a826aaf4c477a3fe";

        bytes[] memory accountProof = new bytes[](9);
        // eth_getProof responds some bytes
        accountProof[0] = worldStateRootRLPEncoded;
        accountProof[1] = hex"f90217b90214f90211a01564179a33d2ff80c3618ab74314aad556cb7652c2d51f7a3aff3a787ecdb29ea03bd6509773c4530091e420ef4921beef2be63ad2429b6e12ba5d7a7f9a6da270a090be43dc028d9eb13a63b5799782f30928e6882b328ab845f320e1eb138d7962a026633ae06c23cd30c5e1cc91cfd7be03652cb9c853fa42538803c8eb631e920fa0711616cf812d7ed5f308b2822bffc5038edac8abedb0f7339c9933387472b495a09266ec8cec3b85e1ea194e79c73a4b2ecc122abffa356b575c31af7e9d3b6921a0a16f884fe19eeaefb8eeb2f017f6ecb24ee5822d5b3bc4be98bcfe374a910761a07973653d008e00cebcc3794f8221fa530d9a18ce77331a3e473e8dc3735943d9a0bc31a4cd1ab5c4ff0bd12f6ffc12f5ef19897df9addc478aa06b223d3087ef9da059aec5d8753109a5893d67ec742b2b51703ecf5920e4947007a6c77265ac41f9a09c0af28e7444278ab0b478870fa98c9f37e9d19681023f8e039f3ce67492e707a008395a6c64c1c76a1e655a28419504519e9957251e83501eef6093971f937c19a04f2a4e14fe7bbf05ea2b75de2bfe95fd33d2c86ff554293ebdf09da7da579cd5a0816ed8d0b69fce577f3c70eceebe8634387716d91a1edc4b3cc9d5feea31ba94a0a270d82ecded0d0712336be6e078794e533721b40698c9b5165b6c420a8a8545a0bcfbc71cc6ee796c58ef28f0d0e453fc08f6326c1891b51512e19af5f4842ffe80";
        accountProof[2] = hex"f90217b90214f90211a0c441ffc1fe3662f328ca995e9cad90cecf26ad98028846b7a1bdb6fe60aa8419a058336ba27c2e0feb5bd8bdeea62ebe54fc4cc05e2376f69e1c721b1cd9098498a07b847e55c107bd976b5984ea7d97d39c68573ae74afd82d4ab9d857cb44e6f82a05f5c1810a0178191798266d171f2f9f9711f5116c5dc4ecccbc29642a24b1873a01da99f321b183e1a2068ac0fd57dccbd637b3fa91b060a80c836ce1ea79fcae0a0f8cf0f8299146bf9d1ec0b8932ddc23ec29cd61daf5cdbe704a5c90f31f0d60ca0407441445132919ff986f169f24e82ce53fe15a444a674ab1604f0924efdd51da0313be5d2f630a30f414aed4012bbe081e55853a55209a3a83045b62f10d74ad2a0ab4a1665cc9ac1dc2f87d98c55e9b893acf84e592635d359a83d0e14181a933da0e4ed4ac12b93b12016ae1c0fd62e6a15b01e617779e8611c27ce22b0b5e78d68a0852127e581d41ec5c58d6a5ccb1b0e7ae90553575b0d9ffb2ac847515671c80fa01ec12bc1938419bebfdc17ed6d10d456fe31202f2dd1534e9bc6b78c95e2b358a000e5a67fdc3cc307a3244b77ddb504867a2cfb0cc9a614a47452d8cfad011af4a0a222a375f0b35461137d84e1beb8cc0e842ea7194784286b0426d80e04ce0ee6a04dc890b4343e041888128a5185860e039b82636d328c52f630007339d445fc0aa00619a2c3c30245bef0821c9f85bc3b79ee2b7f895a4de79ad57f42add8f8cc8d80";
        accountProof[3] = hex"f90217b90214f90211a02b8838e8f55f133d202a53a8b8d9243d936f43b636e8edf4cead5028150ba4bda0199e1c6b8025bdb25824acf47c79f2cb46e9912eea4c7951b1841e6831361cf7a03f9cf217c04256b4b8d32218e998e34a2bb16c17aec758811d9cf2b2510a50a0a06a04facdefe440e0d78718bee9ac31d6693d197ea44bb324156d3bcbdc601763a0d30849e23529944c1763e9de2d3ae6d229b4310bcb2415dec58e5375d04d23efa0a4013ee6afb6af932f3e2d126fbe53f656be59f27df7c700099c91e2a65e2bd3a0233ef3fbc0234cbcb9f76ad4ece6c2f50e480e873226f8f8cef2851d10a7ee33a0b5d1dc30ea1bad8ac548ffd9ac408eabb033f2fcf8d3c1780da97180d89f5997a0a4192803a6131538e307b331f9f842b2302d17492f37537a56a63c36eb01b408a06087dc2726b6a21a4d06d7d73b988925cf3ba2c898d442024468a52f8a4010a8a0bfa291361ed2810c2f8ab0eee7fd894e5915e8ad2d12739d4f380466dc3c7f55a08becd8c73f80d6073df6cceb89e796e669744aa852ce13c7b367fe60c2b34d04a012c2d1a15f1bf98ad00cd0eb061a42eaaf0015a5f4c41a894f249c9a3afc3560a0fef566b4ad9fa37ee9ae59f880f4bb38958c8a62f26ae3668f1dbda3e9fd3b05a0702301629db7bdddcc00dbd348adbcffc890bb1c80fe6ef7a996363adc89770da068b975b9b36fc59378c54d5dd868e53ea8a59248da1dc6c4576d9f781913cd7880";
        accountProof[4] = hex"f90217b90214f90211a0d98672296e62b8aba7e20671ca0476e58efc4ad0c40480e9ced84696bbfa56a8a0d2c53384b6e3b1b3088fcd412af98f85a52b882914a35adb2aa56cd3484997ada09015daa671fe301f656b0ed4f4f2172d683dae40113979a3f710145106031767a00d055b96c4f5804b7d3e4b8159d72bd84ca9e8b4547b504fe2a9933b4359a2d4a0d2560c909a3b2cc465480d1815b06c613d7a2ae7f6c1f00027cf4a57cdc282d7a0c29b7764bdd0df90b1fe350b488ffe69c3c4202f1712c77aab4fa2e0103ae673a06ca16b3f2b111bb14b8b52d36b85b7df2dada9796c2dd0b13f293149cb3e38fba0219ab02566d6474fa0621669616f97f7be79e1cb5886bc75be99be4984bd978ca0d103757173ada974a0f4996e3191ebce8f3ddc61c9db536ff7389c010b03e536a0f65268a6de255bde8ea97282e9f7a858b15b5bde5b9cde5b654c19cd909231f8a06c3ee37ad1762f6fb9da2b3efec779a61036f76b4c97b3ba8ea1339cfc76393ea09b28c2f98e0eedafa97d733d468c1d7a505f8d6b544bbbaf990cdd4781ee765ea0eeda6a2e3dd383ab103d9c14656df77a6b05a566338745325edb03ab344c7404a0ca35c2b85039e6a1fce323649d015876c13702faa510cee4f4a7efaac5456185a00a0e83158f3c174485b6b6ff64f793d0bd578215a685acc86b002bcc99c99f9ba0fd0d0c3d0f27d3e7bc63462df509157e56d03e310ee26a60a4f7dfa87a9e0c2080";
        accountProof[5] = hex"f90217b90214f90211a0f69c09b524b3e7a97fe238809583b7b68f41443a76c0f5d689b371c1df513fc1a0d0f0bcbbd6dae7bd8dd9ba196a34e81c7cc9fea6ac4894a69ec2b5b7bdae2f01a081975fbe995c9a7a55b8e846a70be0d6695c8529b7f564448bf64f2ef25d8c5ca02cd43f9e6fafbe13cc8e845d8c19b51ddc62610119948c635c7e1c9c9998dc22a03b4e6dfe0edcdfbb0b8252f97cc6d2a11f25c571b093cc53aca88d38a94bf827a0e9b70cbde13f142578dba52a5a862122a2332e15c148edda2b9b419528ee9231a014ff7fc46869c016d4ac3b0487a59bf269a4d80fd1afce355f5343d8135bcadaa0d65fafd2a1e02154fcf48c51a354ab294799c6c0444bfadc792ea195e9b9fdefa0edfde20b547f393f4c05f1e6e32b10da328df10d0b231b5c5af4f0d02bdd3492a095fd7a02b5be79308c127233cec06c203ae54ed2c85b69878eeb13abfc9d6a9aa0af6751551d96ea25ae9afb6113a2c13bef56254c3ea24b1a643562fdbdb4100da0c3b3d7526009039e7cf06279d8226f536ccedbed96da7d3f82aa878063bbeb9aa03dcfed22cae1cee772be285fbba92960fe887eb0997eb9a221849e690b2a6917a05c86e58c113f61d4c44bbe0d6c45ee4d4cdf1ecf308d1f0d43f2a284e0bd1300a03eea9d225bd25dc3dc2d48bf156abc17e6d20686624fa5e93ab8b05f42058e34a0794f702cf0ca4e67ad88a9e9ee7d51adf3b3b3aa47621aa5bf0b8cab433176ec80";
        accountProof[6] = hex"f901f7b901f4f901f1a0605770c9b68c1b4e33579a35850c1c44731852d55172ec379b2377e54c359d9ca0d704783a3e1d333129d0305964be5f1af602b860253deddb80c0b36bb71f697ca0b4c43f62e620af02dbeaf9d0e79b62d30041ef97ceb70190e3a1bfa0711ddd21a0ffc993b4e33b8a39b84563804f7439299ca8cc0ce747625fb160baccaac0ae56a073146beddea840ed57473fa066835ba3f5b4a7a950965aa8b97b55604ad328e280a0461d8ad7f395cfca01b2b5173ac2cbc81f0343061a4cad2d93593b29d91ba9baa067a777686549c4b2408aa78e935a777bc447b5055a778faf62a5dda63f5c274ea0903c36605f0616a74dcbb4730437ffefea698cbef452e19a08072830f25c581fa06ff86e3168eb6b77472acb077d925fd36000139a924531125a1cd469152712d2a048fd7f01074966c50c0a3cc68a53a0ea29410c0f9a37595657493ec9dffcd4e9a02358f5f4c8b91b0b865a8f70f22f9f082aefeccd53776ba835ead842ff9d74a0a03f7d16b8024d3f8cd006b4e6cc69ce07c520178254ebafe68ada722871342257a08e1bf934b22c0a817fb470fb0e8c792fd1987f062a1af318de783df5a9c71081a063d0b5247f4a977839a12223db8c2e6f120ea6f0db673f0fb056415745e8015ba0cca532f0172104741733687ad1b87337f554def14726f29fabc556b070d077cf80";
        accountProof[7] = hex"f855b853f8518080808080808080808080a04fc082a60fe2f12e75c8d6dddca59133c0e855e7d412ffbaba8c2117d37aa35780a06bd1536769280b725a364161ed10f1737f8b70938227ae1cdda228f45ac1e168808080";
        accountProof[8] = hex"f86ab868f8669d3a74f1d0cadee872fd4b113921a69b6f137711ffc6bc55289ddac192dcb846f8440180a0f7916f389ccda56e3831e115238b7389b30750886785a3c21265601572698f0fa040ed175bbf1e21348615151831ea7a1164fb6d1bd4e1fa03290f0d97bd122021";
        
        bytes[] memory storageProof = new bytes[](1);
        storageProof[0] = hex"e5a4e3a1209749684f52b5c0717a7ca78127fb56043d637d81763c04e9d30ba4d4746d56e901";
        bytes memory merkleProof = abi.encode(accountProof, storageProof);
        
        vm.startPrank(Alice);
        LibTrieProof_old.verifyWithAccountProof(keccak256(worldStateRootRLPEncoded), contractWhichStoresValue1AtSlot, slotStoredAtTheApp, hex"01", merkleProof);
    }

    // function test_SignalService_proveSignalReceived_L2_L2() public {
    //     uint64 chainId = 11_155_111; // Created the proofs on a deployed
    //         // Sepolia contract, this is why this chainId. This works as a
    //         // static 'chainId' becuase i imitated 2 contracts (L2A and L1
    //         // Signal Service contracts) on Sepolia.
    //     address app = 0x927a146e18294efb36edCacC99D9aCEA6aB16b95; // Mock app,
    //         // actually it is an EOA, but it is ok for tests! Same applies here,
    //         // i imitated everything with one 'app' (Bridge) with my same EOA
    //         // wallet.
    //     bytes[] memory inclusionProof_of_L2A_msgHash = new bytes[](1);

    //     //eth_getProof's result RLP encoded storage proof
    //     inclusionProof_of_L2A_msgHash[0] =
    //         hex"e3a1209749684f52b5c0717a7ca78127fb56043d637d81763c04e9d30ba4d4746d56e901";
    //     bytes32 stateRoot_of_L2 = 0xf7916f389ccda56e3831e115238b7389b30750886785a3c21265601572698f0f; //eth_getProof
    //     // result's storage hash

    //     bytes32 signal_of_L2A_msgHash =
    //         0x21761f7cd1af3972774272b39a0f4602dbcd418325cddb14e156b4bb073d52a8;
    //     bytes[] memory hop_inclusionProof_from_L1_SignalService = new bytes[](1);

    //     hop_inclusionProof_from_L1_SignalService[0] =
    //         hex"e3a120bade38703a7b19341b10a4dd482698dc8ffdd861e83ce41de2980bed39b6a02501";

    //     bytes32 l1_common_relayer_root =
    //         0x5c5fd43df8bcd7ad44cfcae86ed73a11e0baa9a751f0b520d029358ea284833b;

    //     // Important to note, we need to have authorized the "relayers'
    //     // addresses" on the source chain we are claiming.
    //     // (TaikoL1 or TaikoL2 depending on where we are)
    //     vm.startPrank(Alice);
    //     relayer.authorize(address(crossChainSync), bytes32(block.chainid));
    //     relayer.authorize(address(app), bytes32(uint256(chainId)));

    //     vm.startPrank(Alice);
    //     addressManager.setAddress(chainId, "taiko", app);

    //     crossChainSync.setSyncedData("", l1_common_relayer_root);

    //     SignalService.Proof memory p;
    //     p.crossChainSync = address(crossChainSync);
    //     p.height = 10;
    //     p.merkleProof = inclusionProof_of_L2A_msgHash;

    //     // Imagine this scenario: L2A to L2B bridging.
    //     // The 'hop' proof is the one that proves to L2B, that L1 Signal service
    //     // contains the stateRoot (as storage slot / leaf) with value 0x1.
    //     // The 'normal' proof is the one which proves that the resolving
    //     // hop.stateRoot is the one which belongs to L2A, and the proof is
    //     // accordingly.
    //     SignalService.Hop[] memory h = new SignalService.Hop[](1);
    //     h[0].relayerContract = app;
    //     h[0].stateRoot = stateRoot_of_L2;
    //     h[0].merkleProof = hop_inclusionProof_from_L1_SignalService;

    //     p.hops = h;

    //     bool isSignalReceived =
    //         relayer.proveSignalReceived(chainId, app, signal_of_L2A_msgHash, abi.encode(p));
    //     assertEq(isSignalReceived, true);
    // }
}
