const { expect } = require("chai");

describe("BSCToken", function() {
  it("Should return correct token params", async function() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const BSCToken = await ethers.getContractFactory("BSCToken");
    const token = await BSCToken.deploy("Cryptoglasses", "GLS", "1000000000000000000000000000", addr1.address);
    await token.deployed();

    expect(await token.name()).to.equal("Cryptoglasses");
    expect(await token.symbol()).to.equal("GLS");
    expect(await token.decimals()).to.equal(18);
    expect(await token.totalSupply()).to.equal("1000000000000000000000000000");
    expect(await token.balanceOf(addr1.address)).to.equal("1000000000000000000000000000");
    expect(await token.owner()).to.equal(owner.address);
    expect(await token.getOwner()).to.equal(owner.address);

    const transferTx = await token.connect(addr1).transfer(addr2.address, "500000000000000000000000000");

    // wait until the transaction is mined
    await transferTx.wait();

    expect(await token.balanceOf(addr1.address)).to.equal("500000000000000000000000000");
    expect(await token.balanceOf(addr2.address)).to.equal("500000000000000000000000000");
  });
});
