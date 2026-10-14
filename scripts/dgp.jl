import RedGreenAttention as RGA

function main()

    motion_model = RGA.BilliardBrownian(
        RGA.S2V(720.0, 480.0),
        0.1,
        0.001,
    )

    s = RGA.TrialGenSpec(
        ;
        motion_model = motion_model
    )

    istate = RGA.initial_state(s)
end


main();
