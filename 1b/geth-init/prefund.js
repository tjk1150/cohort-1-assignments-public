const from = eth.accounts[0];
const contractDeployer = '0xAcC8C8bBE159061eA5A8B004aA35844839898a2F'; // 내 test account contract 주소
eth.sendTransaction({
  from: from,
  to: contractDeployer,
  value: web3.toWei(100, 'ether'),
});
// PK: 31e71cd8740bb753364962d4c13797ae8388d5429fe59aa3f69339f992b512a0 // 내 test account pk
