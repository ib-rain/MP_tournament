import random as r

'''
This code is a simulation of everyone-with-everyone Matching Pennies tournament.
Strategic form of played game (agent 1 on the left, agent 2 on the top):
             a       b
        A | 1,-1 | -1,1 |
        B | -1,1 | 1,-1 |
Each round is played NUMBER_OF_GAMES times
'''
A='A'
B='B'
a='a'
b='b'

MATRIX={A:{a:(1,-1), b:(-1,1)}, B:{a:(-1,1), b:(1,-1)}}

BRs={A:b, B:a, a:A, b:B}

#My best response to his best response to my best response... ad not infinitum but N.
#0th BR counters what opponent played last, 1st - what opponent will play next time to counter what you played last and so on.
def BR_N(N, S):
    s=S
    for i in range(N+1):
        s=BRs[s]
    return s

NUMBER_OF_GAMES=10000

class Agent:
    def __init__(self, name, action, profile, N):
        self.name = name
        self.action = action
        self.profile = profile
        #Determines first action: 0 for A/a, 1 for B/b. Useless in NE but 1 against 11 is fine.
        self.N = N
        #Power of BR. Useless 3 times in 11.

    def act(self, *arg):
        return self.action(self.profile, self.N, *arg)

def play_1x1(a1, a2):
    a1_win=0
    a1_prev=a1.act(True)
    a2_prev=a2.act(False)
    utility=MATRIX[a1_prev][a2_prev]
    a1_win+=utility[0]
    for i in range(NUMBER_OF_GAMES-1):
        a1_save=a1_prev
        a1_prev=a1.act(True, a1_prev, a2_prev)
        a2_prev=a2.act(False, a2_prev, a1_save)
        utility=MATRIX[a1_prev][a2_prev]
        a1_win+=utility[0]
    print("{}\t{}\t{}\t{}".format(a1.name, a2.name, a1_win, a1_win>0))
    return a1_win

STRATS={True:(A,B), False:(a,b)}
#Shortcut to diffirintiate between A1 and A2 strategies (different BRs).

def NE(*arg):
    if r.getrandbits(1)==0:
        return STRATS[arg[2]][0]
    return STRATS[arg[2]][1]

def always_s(*arg):
    return STRATS[arg[2]][arg[0]]

def BRN_s(*arg):
    if len(arg)==3:
        return STRATS[arg[2]][arg[0]]
    if arg[1]%2==0:
        return BR_N(arg[1], arg[4])
    return BR_N(arg[1], arg[3])

def print_results(agent_list):
    print("A1\tA1 win\tA2\tA2 win\tVictory?".format())
    for a1 in agent_list:
        a1_sum_win = 0
        for a2 in agent_list:
            a1_sum_win += play_1x1(a1, a2)
        print("\t\t\t\t{}\t{}".format(a1.name, a1_sum_win))


def main():
    p1 = Agent("NE", NE, '', '')
    p2 = Agent("Always_A", always_s, 0, '')
    p3 = Agent("Always_B", always_s, 1, '')
    p4 = Agent("BR0_A", BRN_s, 0, 0)
    p5 = Agent("BR0_B", BRN_s, 1, 0)
    p6 = Agent("BR1_A", BRN_s, 0, 1)
    p7 = Agent("BR1_B", BRN_s, 1, 1)
    p8 = Agent("BR2_A", BRN_s, 0, 2)
    p9 = Agent("BR2_B", BRN_s, 1, 2)
    p10 = Agent("BR3_A", BRN_s, 0, 3)
    p11 = Agent("BR3_B", BRN_s, 1, 3)
    
    agent_list=[p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11]
    print_results(agent_list)

main()
