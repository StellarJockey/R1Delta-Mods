function main() {
    if (IsLobby())
       return
    thread RefillNadesForAll()
}

function RefillNadesForAll() {
    while (1) {
        foreach (player in GetPlayerArray()) {
            if(player.IsTitan())
                continue;

            local offhand = player.GetOffhandWeapon( 0 )
            if (offhand) {
                local currentAmmo = offhand.GetWeaponPrimaryClipCount()
				local maxNades = 2
				if (PlayerHasPassive(player, 0x20000)) // PAS_ORDNANCE_PACK
					maxNades = 3
                if(currentAmmo < maxNades)
                    offhand.SetWeaponPrimaryClipCount( currentAmmo + 1 )
            }
        }
        wait 16;
    }
}

main()
