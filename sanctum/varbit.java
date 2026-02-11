// This is for the symbols for Nakatra <3

if (VarManager.getVarbitValue(55760) != 0) {
                    int location = VarManager.getVarbitValue(55767);
                    int middle = VarManager.getVarbitValue(55758);
                    int left = VarManager.getVarbitValue(55760);
                    int right = VarManager.getVarbitValue(55759);
                    Coordinate middlecord = new Coordinate(nakax, nakay - 5, 1);
                    Coordinate leftcord = new Coordinate(nakax + 5, nakay, 1);
                    Coordinate rightcord = new Coordinate(nakax - 5, nakay, 1);
                    if (location == middle) {
                        fightpostion = middlecord;
                    } else if (location == left) {
                        fightpostion = leftcord;
                    } else {
                        fightpostion = rightcord;
                    }
                }
