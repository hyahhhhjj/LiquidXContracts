from brownie import interface, StakePoolFactory, LiquidXAggregator, ManagerAccount, MintableERC20, AccountsGuard, CollectFeesTest, LiquidXStakePool

from scripts.helpful_scripts import get_account
from web3 import Web3

totalSupply = Web3.toWei(1000000, "ether")
MAX_LEVERAGE = 1048576
# pair2 0x5f79ABacC763A61AD7ffEaa01a8b6Fd9F1856C2e tokenX(TBUSD): 0x6658081AbdAA15336b54763662B46966008E8953, tokenY(WBNB): 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd binstep:15
# StakePoolFactory deployed at: 0x0C2654000d6e9Cc0581F034478b184c658bC8236
# pool1(TBUSDL): 0x6d36a16987c043f4062FB6fE46076B4E358D7B81 pool2(WBNBL): 0xEA159998EA0615904FA6af263c6b52231336BE06
# LiquidXAggregator deployed at: 0x917E3bcb5665bcd46D7a758b4F37C84D87790921
# AccountsGuard deployed at: 0xD758Ccf8e54f3fd842A0B27Ce94bdf6Eff8E4e5a
def main():

    # step4-1
    # accountsGuard = AccountsGuard.deploy({"from": get_account()}, publish_source=False)
    # step4-2
    # aggregator = LiquidXAggregator.deploy("0xD758Ccf8e54f3fd842A0B27Ce94bdf6Eff8E4e5a", {"from": get_account()}, publish_source=False)
    # step4-3
    # accountsGuard = AccountsGuard.at("0xD758Ccf8e54f3fd842A0B27Ce94bdf6Eff8E4e5a")
    # accountsGuard.updateAggregator("0x917E3bcb5665bcd46D7a758b4F37C84D87790921", {"from": get_account()})
    # step4-4
    # stakePool = StakePoolFactory.deploy("0x917E3bcb5665bcd46D7a758b4F37C84D87790921",{"from": get_account()}, publish_source=False)
    # step4-5
    # stakePool = StakePoolFactory.at("0x0C2654000d6e9Cc0581F034478b184c658bC8236")
    # stakePool.addStakePool("tbusd-l","TBUSDL","0x6658081AbdAA15336b54763662B46966008E8953",MAX_LEVERAGE,{"from": get_account()})
    # stakePool.addStakePool("wbnb-l", "WBNBL", "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",MAX_LEVERAGE,{"from": get_account()})
    # print(stakePool.getStakePoolsLength())
    # step4-6
    # stakePool = StakePoolFactory.at("0x0C2654000d6e9Cc0581F034478b184c658bC8236")
    # print(stakePool.getStakePoolByIndex(0))
    # print(stakePool.getStakePoolByIndex(1))
    # step5
    # aggregator = LiquidXAggregator.at("0x917E3bcb5665bcd46D7a758b4F37C84D87790921")
    # aggregator.addStakePool("0x6d36a16987c043f4062FB6fE46076B4E358D7B81", {"from": get_account()})
    # aggregator.addStakePool("0xEA159998EA0615904FA6af263c6b52231336BE06", {"from": get_account()})
    # step6
    # aggregator = LiquidXAggregator.at("0x917E3bcb5665bcd46D7a758b4F37C84D87790921")
    # aggregator.addNewLBPair("0x5f79ABacC763A61AD7ffEaa01a8b6Fd9F1856C2e", "0x6658081AbdAA15336b54763662B46966008E8953", "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", 15, {"from": get_account()})
    # step7
    # aggregator = LiquidXAggregator.at("0x2e8A8209a3017001Ae1344d1869b99C15fB57Edd")
    # aggregator.createManagerAccount("0xFA90F66C7198a33C093AB6fD8719C095b712aC4d", "0x7BFd7192E76D950832c77BB412aaE841049D8D9B", {"from": get_account()})
    # step8
    # aggregator = LiquidXAggregator.at("0x2e8A8209a3017001Ae1344d1869b99C15fB57Edd")
    # print(aggregator.getAccount("0xFA90F66C7198a33C093AB6fD8719C095b712aC4d"))
    # step9 account address 0xf72FDd2b4c2f1358c826E62A2183b36D678a3501
    # account = interface.IManagerAccount("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # tokenx = interface.IERC20("0x912CE59144191C1204E64559FE8253a0e49E6548")
    # tokeny = interface.IERC20("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")
    # tokenx.approve("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501", totalSupply, {"from": get_account()})
    # tokeny.approve("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501", totalSupply, {"from": get_account()})
    # step 10 test with deposit
    # account = interface.IManagerAccount("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # account.deposit("0x912CE59144191C1204E64559FE8253a0e49E6548", 5706226538191830013315, {"from": get_account()})
    # account.deposit("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", 3000000000000000000, {"from": get_account()})
    # step11
    # account = interface.IManagerAccount("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # print(account.getAccountBalanceAvailable("0x912CE59144191C1204E64559FE8253a0e49E6548"))
    # step12
    # account = interface.IManagerAccount("0xE8cF2d295ed684Be31ff7cA4ad50084Ca43fdB86")
    # account.withdraw("0x912CE59144191C1204E64559FE8253a0e49E6548", 13, {"from": get_account()})
    # account.withdraw("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", 1, {"from": get_account()})
    # step13 add/remove liquidity test(total distribution <= 1e18)
    # account = ManagerAccount.at("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # account.addLiquidity("0xafebf9bba7984954e42d7551ab0ce47130bfdc0a",
    #                      ("0x912CE59144191C1204E64559FE8253a0e49E6548",
    #                      "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    #                      20,
    #                      0, 3460144782204484302, 0, 0,
    #                      8385005, 8385005, [-2, -1],
    #                      [0, 0],
    #                      [5e17, 5e17],
    #                      "0xFA90F66C7198a33C093AB6fD8719C095b712aC4d",
    #                      1693399470),
    #                      {"from": get_account()})
    # step15 lb amount check
    # account = ManagerAccount.at("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # print(account.getMMLBPairToIdToAmount("0xafebf9bba7984954e42d7551ab0ce47130bfdc0a", 8385003))
    # step16-0
    # account = ManagerAccount.at("0xE8cF2d295ed684Be31ff7cA4ad50084Ca43fdB86")
    # print(account.getMMLBPairToIdSetLength("0xafebf9bba7984954e42d7551ab0ce47130bfdc0a"))
    # step16 remove
    # account = ManagerAccount.at("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # account.removeLiquidity("0xafebf9bba7984954e42d7551ab0ce47130bfdc0a", [8385004, 8385003], [1730072391102242151, 1730072391102242151], 1693399470, {"from": get_account()})
    # step17
    # account = ManagerAccount.at("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # account.repay("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", {"from": get_account()})
    # step18
    # stakePool = LiquidXStakePool.at("0x1B931459EdaBd4C3a9c55527Cea45944ff9Fc94a")
    # print(stakePool.getTotalReserve())
    # step19
    # stakeToken = interface.IERC20("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")
    # print(stakeToken.balanceOf("0x1B931459EdaBd4C3a9c55527Cea45944ff9Fc94a"))
    # step20 8384991: 829526427266995592 8384990: 1241806028842807773 8384989: 3565333054529931566 8384988: 900000000000000000 8384987: 600000000000000000
    # current arb: 5842043535050810477140 aeth: 3316637413377872772
    # step20
    # account = ManagerAccount.at("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # print(account.getCredit())
    # step21
    # aeth = interface.IERC20("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")
    # aeth.approve("0xE6202e67D45C95877c524139D7ce972e8c11d2eB", totalSupply, {"from": get_account()})
    # step22-1
    # token = interface.IERC20("0x912CE59144191C1204E64559FE8253a0e49E6548")
    # token.approve("0x1C74C6E96A9C40b9C04Ef4D7515fd7F24d33A7E9", totalSupply, {"from": get_account()})
    # step22-2
    # pool = LiquidXStakePool.at("0x1C74C6E96A9C40b9C04Ef4D7515fd7F24d33A7E9")
    # pool.burnShare(Web3.toWei(0.03, "ether"), {"from": get_account()})
    # step23
    # account = ManagerAccount.at("0xf72FDd2b4c2f1358c826E62A2183b36D678a3501")
    # account.borrow("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",663327482675574554, {"from": get_account()})
    # step24
    # pool = LiquidXStakePool.at("0x1C74C6E96A9C40b9C04Ef4D7515fd7F24d33A7E9")
    # print(pool.getTotalReserve())
