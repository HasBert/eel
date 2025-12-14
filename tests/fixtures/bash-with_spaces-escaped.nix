let
  var = "Friends";
  bashStr = /* bash */ ''
    SOME_VAR="we are"

    echo "Hi, ${var} ''$SOME_VAR"
  '';
in
x
