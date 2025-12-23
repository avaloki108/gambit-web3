methods {
    function add(uint256 a, uint256 b) returns (uint256) envfree;
}

rules {
    rule testAddition {
        uint256 a = 5;
        uint256 b = 3;
        uint256 result = add(a, b);
        assert result == 8, "5 + 3 should equal 8";
    }
}