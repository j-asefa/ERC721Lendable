# Overview

ERC721Lendable is an extension to the ERC721 standard that allows token owners to trustlessly lend their tokens to others for a fixed duration. 

`ERC721Lendable` token holders can transfer ownership of their assets to others for a fixed duration. Once the duration is over, lenders can reclaim ownership of their tokens. This functionality opens up several interesting use cases and provides additional value to NFTs that follow this implementation.

**NOTE: There are currently no tests in this repository nd the code has not been audited. It is very likely that there are bugs in the code that will cause loss of funds if used as-is.**

# How it works

When an `ERC721Lendable` token is lent out, the ownership of the token is transferred to the borrower. This means that any calls to the IERC721 functions `ownerOf`, `balanceOf`, `approve` etc. will behave exactly as if the borrower is the true owner of the NFT. 

To prevent malicious activity, the `ERC721Lendable` implementation shown here overrides OpenZeppelin's `_beforeTokenTransfer` to prevent borrowers from transferring tokens (unless as part of a new loan).

ERC721Lendable collections allow for lenders and borrowers to speculate on the value of owning a token during a given time frame. This can provide significant value in the context of NFTs where teams routinely take wallet snapshots and provide airdrops and token gated access to various goods and services. 

# Use Cases

* A simple example use-case is for token gated IRL events: let's say some members of the NFT community decide to hold a token gated event in NYC. If the NFT is implemented as a standard ERC721 token with no lendable functionality, then token holders outside of NYC get little benefit, unless they are willing to pay for travel to NYC. If, instead, the NFT collection is implemented as an `ERC721Lendable`, then token holders outside of NYC have a way to generate some yield from their token by lending it out to people who want to attend, but don't own a token. When the event closes, the lender can reclaim their token.  

* Another interesting use case centers around whitelists and airdrops: take the example of a membership pass NFT that is doing a PFP airdrop for membership token holders. Let's say the PFP airdrop is happening in 1 week. As a membership NFT holder you have the right to mint the project's PFP for free. You imagine that, post-mint, the project will not do very well and propbably have a 0.5 ETH floor price. Let's now imagine someone else who is not a membership token holder, but wants to mint the PFP. They imagine the post-mint floor is going to be 2ETH. They are willing to pay 1 ETH today for the right to mint this upcoming PFP for free (rather than having to wait and buy on secondary for 2 ETH). The `ERC721Lendable` token holder can lend their membership pass out to this prospective borrower for 1 ETH for a duration of 1 week. Both parties are happy with this trade, and an additional 1 ETH of value was generated for the token holder.

* Similar use cases exist for token gated metaverse events where the token holder cannot attend for one reason or another.

By making NFT collections lendable, token holders are given additional control over their holdings that provide them with the ability to generate further yield.

Notice that the lender gives up all token privileges for the duration of the loan, which means that the borrower is eligible for any token related benefits (such as airdrops, token gated merchandise, token gated IRL minting etc.) while holding the token. Since the lender is taking on a small amount of risk of losing out on these benefits, the lender should expect to be paid a small sum. This is where `ERC721Lendable` tokens allow for composability via lending markets.


# Lending Markets

`ERC721Lendable` implements a very simple interface that only supports lending tokens and reclaiming loans, and does not make any assumptions about loan payments or terms. This allows for interesting markets to be formed around these tokens. 

Existing NFT lending markets (such as NFTFi or Arcade) can be extended to simply call `loanFrom` on the `ERC721Lendable` token when a loan is made. This will allow the borrower to take possession of the token, instead of it being held by the lending platform for the loan duration.

Other lending markets can be implemented that support orderbooks for NFT loans (very similar to OpenSea's implementation of the Wyvern protocol). The platform can consolidate bids into an orderbook along the price and duration dimensions. Prospective borrowers can post a given amount of ETH and a loan duration into the lending platform's contract with a specified Good-Til-Date for the bid. If an ERC721Lendable holder feels that a bidder's terms are sufficently attractive, they can accept the bid, which will atomically pay them the bonded ETH up-front, and lend out the token to the bidder. Similarly, an ERC721Lendable token holder can list their token for loan for a given price and duration. The platform can then allow prospective borrowers to "Borrow Now", which will cause the borrower to transfer the loan amount directly to the lender, and will then lend the token to the borrower. The mechanism is very similar to OpenSea's Wyvern protocol implementation.



### Sub-Loans

Borrowers can lend out their borrowed tokens again under new terms, and generate additional yield on their borrowed tokens. This is similar to the concept of "sub-letting" in rental agreements. The only limits on Borrowers "sub-letting" their borrowed tokens is that the new loan duration must be shorter than the parent loan duration (to allow for the original lender to reclaim their token at the end of their loan).

