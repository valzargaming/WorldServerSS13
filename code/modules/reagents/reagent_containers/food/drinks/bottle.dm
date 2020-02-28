///////////////////////////////////////////////Alchohol bottles! -Agouri //////////////////////////
//Functionally identical to regular drinks. The only difference is that the default bottle size is 100. - Darem
//Bottles now weaken and break when smashed on people's heads. - Giacom

/obj/item/weapon/reagent_containers/food/drinks/bottle
	amount_per_transfer_from_this = 10
	volume = 100
	item_state = "broken_beer" //Generic held-item sprite until unique ones are made.
	force = 6
	var/smash_duration = 5 //Directly relates to the 'weaken' duration. Lowered by armor (i.e. helmets)
	var/isGlass = 1 //Whether the 'bottle' is made of glass or not so that milk cartons dont shatter when someone gets hit by it

	var/obj/item/weapon/reagent_containers/glass/rag/rag = null
	var/rag_underlay = "rag"
	drop_sound = 'sound/items/drop/glass.ogg'

	on_reagent_change() return // To suppress price updating. Bottles have their own price tags.

/obj/item/weapon/reagent_containers/food/drinks/bottle/New()
	..()
	if(isGlass) unacidable = 1

/obj/item/weapon/reagent_containers/food/drinks/bottle/Destroy()
	if(rag)
		rag.forceMove(src.loc)
	rag = null
	return ..()

//when thrown on impact, bottles smash and spill their contents
/obj/item/weapon/reagent_containers/food/drinks/bottle/throw_impact(atom/hit_atom, var/speed)
	..()

	var/mob/M = thrower
	if(isGlass && istype(M) && M.a_intent == I_HURT)
		var/throw_dist = get_dist(throw_source, loc)
		if(speed >= throw_speed && smash_check(throw_dist)) //not as reliable as smashing directly
			if(reagents)
				hit_atom.visible_message("<span class='notice'>The contents of \the [src] splash all over [hit_atom]!</span>")
				reagents.splash(hit_atom, reagents.total_volume)
			src.smash(loc, hit_atom)

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/smash_check(var/distance)
	if(!isGlass || !smash_duration)
		return 0

	var/list/chance_table = list(100, 95, 90, 85, 75, 55, 35) //starting from distance 0
	var/idx = max(distance + 1, 1) //since list indices start at 1
	if(idx > chance_table.len)
		return 0
	return prob(chance_table[idx])

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/smash(var/newloc, atom/against = null)
	if(ismob(loc))
		var/mob/M = loc
		M.drop_from_inventory(src)

	//Creates a shattering noise and replaces the bottle with a broken_bottle
	var/obj/item/weapon/broken_bottle/B = new /obj/item/weapon/broken_bottle(newloc)
	if(prob(33))
		new/obj/item/weapon/material/shard(newloc) // Create a glass shard at the target's location!
	B.icon_state = src.icon_state

	var/icon/I = new('icons/obj/drinks.dmi', src.icon_state)
	I.Blend(B.broken_outline, ICON_OVERLAY, rand(5), 1)
	I.SwapColor(rgb(255, 0, 220, 255), rgb(0, 0, 0, 0))
	B.icon = I

	if(rag && rag.on_fire && isliving(against))
		rag.forceMove(loc)
		var/mob/living/L = against
		L.IgniteMob()

	playsound(src, "shatter", 70, 1)
	src.transfer_fingerprints_to(B)

	qdel(src)
	return B

/obj/item/weapon/reagent_containers/food/drinks/bottle/verb/smash_bottle()
	set name = "Smash Bottle"
	set category = "Object"

	var/list/things_to_smash_on = list()
	for(var/atom/A in range (1, usr))
		if(A.density && usr.Adjacent(A) && !istype(A, /mob))
			things_to_smash_on += A

	var/atom/choice = input("Select what you want to smash the bottle on.") as null|anything in things_to_smash_on
	if(!choice)
		return
	if(!(choice.density && usr.Adjacent(choice)))
		usr << "<span class='warning'>You must stay close to your target! You moved away from \the [choice]</span>"
		return

	usr.put_in_hands(src.smash(usr.loc, choice))
	usr.visible_message("<span class='danger'>\The [usr] smashed \the [src] on \the [choice]!</span>")
	usr << "<span class='danger'>You smash \the [src] on \the [choice]!</span>"

/obj/item/weapon/reagent_containers/food/drinks/bottle/attackby(obj/item/W, mob/user)
	if(!rag && istype(W, /obj/item/weapon/reagent_containers/glass/rag))
		insert_rag(W, user)
		return
	if(rag && istype(W, /obj/item/weapon/flame))
		rag.attackby(W, user)
		return
	..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/attack_self(mob/user)
	if(rag)
		remove_rag(user)
	else
		..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/insert_rag(obj/item/weapon/reagent_containers/glass/rag/R, mob/user)
	if(!isGlass || rag) return
	if(user.unEquip(R))
		user << "<span class='notice'>You stuff [R] into [src].</span>"
		rag = R
		rag.forceMove(src)
		flags &= ~OPENCONTAINER
		update_icon()

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/remove_rag(mob/user)
	if(!rag) return
	user.put_in_hands(rag)
	rag = null
	flags |= (initial(flags) & OPENCONTAINER)
	update_icon()

/obj/item/weapon/reagent_containers/food/drinks/bottle/open(mob/user)
	if(rag) return
	..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/update_icon()
	underlays.Cut()
	if(rag)
		var/underlay_image = image(icon='icons/obj/drinks.dmi', icon_state=rag.on_fire? "[rag_underlay]_lit" : rag_underlay)
		underlays += underlay_image
		set_light(rag.light_range, rag.light_power, rag.light_color)
	else
		set_light(0)

/obj/item/weapon/reagent_containers/food/drinks/bottle/apply_hit_effect(mob/living/target, mob/living/user, var/hit_zone)
	var/blocked = ..()

	if(user.a_intent != I_HURT)
		return
	if(!smash_check(1))
		return //won't always break on the first hit

	// You are going to knock someone out for longer if they are not wearing a helmet.
	var/weaken_duration = 0
	if(blocked < 100)
		weaken_duration = smash_duration + min(0, force - target.getarmor(hit_zone, "melee") + 10)

	if(hit_zone == "head" && istype(target, /mob/living/carbon/))
		user.visible_message("<span class='danger'>\The [user] smashes [src] over [target]'s head!</span>")
		if(weaken_duration)
			target.apply_effect(min(weaken_duration, 5), WEAKEN, blocked) // Never weaken more than a flash!
	else
		user.visible_message("<span class='danger'>\The [user] smashes [src] into [target]!</span>")

	//The reagents in the bottle splash all over the target, thanks for the idea Nodrak
	if(reagents)
		user.visible_message("<span class='notice'>The contents of \the [src] splash all over [target]!</span>")
		reagents.splash(target, reagents.total_volume)

	//Finally, smash the bottle. This kills (qdel) the bottle.
	var/obj/item/weapon/broken_bottle/B = smash(target.loc, target)
	user.put_in_active_hand(B)

//Keeping this here for now, I'll ask if I should keep it here.
/obj/item/weapon/broken_bottle
	name = "Broken Bottle"
	desc = "A bottle with a sharp broken bottom."
	icon = 'icons/obj/drinks.dmi'
	icon_state = "broken_bottle"
	force = 10
	throwforce = 5
	throw_speed = 3
	throw_range = 5
	item_state = "beer"
	attack_verb = list("stabbed", "slashed", "attacked")
	sharp = 1
	edge = 0
	var/icon/broken_outline = icon('icons/obj/drinks.dmi', "broken")

/obj/item/weapon/broken_bottle/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	playsound(loc, 'sound/weapons/bladeslice.ogg', 50, 1, -1)
	return ..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/gin
	name = "Griffeater Gin"
	desc = "A bottle of high quality gin, produced in Alpha Centauri."
	icon_state = "ginbottle"
	center_of_mass = list("x"=16, "y"=4)

/obj/item/weapon/reagent_containers/food/drinks/bottle/gin/New()
	..()
	reagents.add_reagent("gin", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/whiskey
	name = "Uncle Git's Special Reserve"
	desc = "A premium single-malt whiskey, gently matured inside the tunnels of a nuclear shelter."
	icon_state = "whiskeybottle"
	center_of_mass = list("x"=16, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/whiskey/New()
	..()
	reagents.add_reagent("whiskey", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/specialwhiskey
	name = "Special Blend Whiskey"
	desc = "Just when you thought regular whiskey was good... This silky, amber goodness has to come along and ruin everything."
	icon_state = "specialwhiskeybottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/specialwhiskey/New()
	..()
	reagents.add_reagent("specialwhiskey", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka
	name = "Tunguska Triple Distilled"
	desc = "Aah, vodka. Prime choice of drink and fuel by Russians worldwide."
	icon_state = "vodkabottle"
	center_of_mass = list("x"=17, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka/New()
	..()
	reagents.add_reagent("vodka", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vodkakora
	name = "Kora Vodka"
	desc = "The most expensive vodka ever distilled. It comes in a diamond-studded silver bottle."
	icon_state = "korabottle"
	center_of_mass = list("x"=17, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vodkakora/New()
	..()
	reagents.add_reagent("vodkakora", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/tequilla
	name = "Caccavo Guaranteed Quality Tequilla"
	desc = "Made from premium petroleum distillates, pure thalidomide and other fine quality ingredients!"
	icon_state = "tequillabottle"
	center_of_mass = list("x"=16, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/tequilla/New()
	..()
	reagents.add_reagent("tequilla", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/bottleofnothing
	name = "Bottle of Nothing"
	desc = "A bottle filled with nothing"
	icon_state = "bottleofnothing"
	center_of_mass = list("x"=17, "y"=5)

/obj/item/weapon/reagent_containers/food/drinks/bottle/bottleofnothing/New()
	..()
	reagents.add_reagent("nothing", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/patron
	name = "Wrapp Artiste Patron"
	desc = "Silver laced tequilla, served in space night clubs across the galaxy."
	icon_state = "patronbottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/patron/New()
	..()
	reagents.add_reagent("patron", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/rum
	name = "Captain Pete's Cuban Spiced Rum"
	desc = "This isn't just rum, oh no. It's practically Cuba in a bottle."
	icon_state = "rumbottle"
	center_of_mass = list("x"=16, "y"=8)

/obj/item/weapon/reagent_containers/food/drinks/bottle/rum/New()
	..()
	reagents.add_reagent("rum", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/holywater
	name = "Flask of Holy Water"
	desc = "A flask of the chaplain's holy water."
	icon_state = "holyflask"
	center_of_mass = list("x"=17, "y"=10)

/obj/item/weapon/reagent_containers/food/drinks/bottle/holywater/New()
	..()
	reagents.add_reagent("holywater", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vermouth
	name = "Goldeneye Vermouth"
	desc = "Sweet, sweet dryness~"
	icon_state = "vermouthbottle"
	center_of_mass = list("x"=17, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vermouth/New()
	..()
	reagents.add_reagent("vermouth", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/kahlua
	name = "Robert Robust's Coffee Liqueur"
	desc = "A widely known, Mexican coffee-flavoured liqueur. In production since 1936."
	icon_state = "kahluabottle"
	center_of_mass = list("x"=17, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/kahlua/New()
	..()
	reagents.add_reagent("kahlua", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/goldschlager
	name = "College Girl Goldschlager"
	desc = "Because they are the only ones who will drink 100 proof cinnamon schnapps."
	icon_state = "goldschlagerbottle"
	center_of_mass = list("x"=15, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/goldschlager/New()
	..()
	reagents.add_reagent("goldschlager", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/cognac
	name = "Chateau De Baton Premium Cognac"
	desc = "A sweet and strongly alchoholic drink, made after numerous distillations and years of maturing."
	icon_state = "cognacbottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/cognac/New()
	..()
	reagents.add_reagent("cognac", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/wine
	name = "Doublebeard Bearded Special Wine"
	desc = "Cheap cooking wine pretending to be drinkable."
	icon_state = "winebottle"
	center_of_mass = list("x"=16, "y"=4)

/obj/item/weapon/reagent_containers/food/drinks/bottle/wine/New()
	..()
	reagents.add_reagent("wine", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/amontillado
	name = "Amontillado Viejo 1850"
	desc = "An expensive wine sourced from a collection of casks found buried in Italy."
	icon_state = "amontillado"
	center_of_mass = list("x"=16, "y"=4)

/obj/item/weapon/reagent_containers/food/drinks/bottle/amontillado/New()
	..()
	reagents.add_reagent("amontilladowine", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/absinthe
	name = "Jailbreaker Verte"
	desc = "One sip of this and you just know you're gonna have a good time."
	icon_state = "absinthebottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/absinthe/New()
	..()
	reagents.add_reagent("absinthe", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/melonliquor
	name = "Emeraldine Melon Liquor"
	desc = "A bottle of 46 proof Emeraldine Melon Liquor. Sweet and light."
	icon_state = "alco-green" //Placeholder.
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/melonliquor/New()
	..()
	reagents.add_reagent("melonliquor", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/bluecuracao
	name = "Miss Blue Curacao"
	desc = "A fruity, exceptionally azure drink. Does not allow the imbiber to use the fifth magic."
	icon_state = "alco-blue" //Placeholder.
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/bluecuracao/New()
	..()
	reagents.add_reagent("bluecuracao", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/grenadine
	name = "Briar Rose Grenadine Syrup"
	desc = "Sweet and tangy, a bar syrup used to add color or flavor to drinks."
	icon_state = "grenadinebottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/grenadine/New()
	..()
	reagents.add_reagent("grenadine", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/cola
	name = "\improper Space Cola"
	desc = "Cola. in space"
	icon_state = "colabottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/cola/New()
	..()
	reagents.add_reagent("cola", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/space_up
	name = "\improper Space-Up"
	desc = "Tastes like a hull breach in your mouth."
	icon_state = "space-up_bottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/space_up/New()
	..()
	reagents.add_reagent("space_up", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/space_mountain_wind
	name = "\improper Space Mountain Wind"
	desc = "Blows right through you like a space wind."
	icon_state = "space_mountain_wind_bottle"
	center_of_mass = list("x"=16, "y"=6)

/obj/item/weapon/reagent_containers/food/drinks/bottle/space_mountain_wind/New()
	..()
	reagents.add_reagent("spacemountainwind", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/pwine
	name = "Warlock's Velvet"
	desc = "What a delightful packaging for a surely high quality wine! The vintage must be amazing!"
	icon_state = "pwinebottle"
	center_of_mass = list("x"=16, "y"=4)

/obj/item/weapon/reagent_containers/food/drinks/bottle/pwine/New()
	..()
	reagents.add_reagent("pwine", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/redeemersbrew
	name = "Redeemer's Brew"
	desc = "Just opening the top of this bottle makes you feel a bit tipsy. Not for the faint of heart."
	icon_state = "redeemersbrew"
	center_of_mass = list("x"=16, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/redeemersbrew/New()
	..()
	reagents.add_reagent("unathiliquor", 100)

//////////////////////////JUICES AND STUFF ///////////////////////

/obj/item/weapon/reagent_containers/food/drinks/bottle/orangejuice
	name = "Orange Juice"
	desc = "Full of vitamins and deliciousness!"
	icon_state = "orangejuice"
	item_state = "carton"
	center_of_mass = list("x"=16, "y"=7)
	isGlass = 0

/obj/item/weapon/reagent_containers/food/drinks/bottle/orangejuice/New()
	..()
	reagents.add_reagent("orangejuice", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/applejuice
	name = "Apple Juice"
	desc = "Squeezed, pressed and ground to perfection!"
	icon_state = "applejuice"
	item_state = "carton"
	center_of_mass = list("x"=16, "y"=7)
	isGlass = 0

/obj/item/weapon/reagent_containers/food/drinks/bottle/applejuice/New()
	..()
	reagents.add_reagent("applejuice", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/milk
	name = "Large Milk Carton"
	desc = "It's milk. This carton's large enough to serve your biggest milk drinkers."
	icon_state = "milk"
	item_state = "carton"
	center_of_mass = list("x"=16, "y"=9)
	isGlass = 0

/obj/item/weapon/reagent_containers/food/drinks/bottle/milk/New()
	..()
	reagents.add_reagent("milk", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/cream
	name = "Milk Cream"
	desc = "It's cream. Made from milk. What else did you think you'd find in there?"
	icon_state = "cream"
	item_state = "carton"
	center_of_mass = list("x"=16, "y"=8)
	isGlass = 0

/obj/item/weapon/reagent_containers/food/drinks/bottle/cream/New()
	..()
	reagents.add_reagent("cream", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/tomatojuice
	name = "Tomato Juice"
	desc = "Well, at least it LOOKS like tomato juice. You can't tell with all that redness."
	icon_state = "tomatojuice"
	item_state = "carton"
	center_of_mass = list("x"=16, "y"=8)
	isGlass = 0

/obj/item/weapon/reagent_containers/food/drinks/bottle/tomatojuice/New()
	..()
	reagents.add_reagent("tomatojuice", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/limejuice
	name = "Lime Juice"
	desc = "Sweet-sour goodness."
	icon_state = "limejuice"
	item_state = "carton"
	center_of_mass = list("x"=16, "y"=8)
	isGlass = 0

/obj/item/weapon/reagent_containers/food/drinks/bottle/limejuice/New()
	..()
	reagents.add_reagent("limejuice", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/lemonjuice
	name = "Lemon Juice"
	desc = "Sweet-sour goodness. Minus the sweet."
	icon_state = "lemonjuice"
	item_state = "carton"
	center_of_mass = list("x"=16, "y"=8)
	isGlass = 0

/obj/item/weapon/reagent_containers/food/drinks/bottle/lemonjuice/New()
	..()
	reagents.add_reagent("lemonjuice", 100)

//Small bottles
/obj/item/weapon/reagent_containers/food/drinks/bottle/small
	volume = 50
	smash_duration = 1
	flags = 0 //starts closed
	rag_underlay = "rag_small"

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer
	name = "space beer"
	desc = "Contains only water, malt and hops."
	icon_state = "beer"
	center_of_mass = list("x"=16, "y"=12)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer/New()
	..()
	reagents.add_reagent("beer", 30)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/ale
	name = "\improper Magm-Ale"
	desc = "A true dorf's drink of choice."
	icon_state = "alebottle"
	item_state = "beer"
	center_of_mass = list("x"=16, "y"=10)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/ale/New()
	..()
	reagents.add_reagent("ale", 30)

/obj/item/weapon/reagent_containers/food/drinks/bottle/sake
	name = "Mono-No-Aware Luxury Sake"
	desc = "Dry alcohol made from rice, a favorite of businessmen."
	icon_state = "sakebottle"
	center_of_mass = list("x"=16, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/sake/New()
	..()
	reagents.add_reagent("sake", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/champagne
	name = "Gilthari Luxury Champagne"
	desc = "For those special occassions."
	icon_state = "champagne"

/obj/item/weapon/reagent_containers/food/drinks/bottle/champagne/New()
	..()
	reagents.add_reagent("champagne", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/peppermintschnapps
	name = "Dr. Bone's Peppermint Schnapps"
	desc = "A flavoured grain liqueur with a fresh, minty taste."
	icon_state = "schnapps_pep"
	center_of_mass = list("x"=16, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/peppermintschnapps/New()
	. = ..()
	reagents.add_reagent("schnapps_pep", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/peachschnapps
	name = "Dr. Bone's Peach Schnapps"
	desc = "A flavoured grain liqueur with a fruity peach taste."
	icon_state = "schnapps_pea"
	center_of_mass = list("x"=16, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/peachschnapps/New()
	. = ..()
	reagents.add_reagent("schnapps_pea", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/lemonadeschnapps
	name = "Dr. Bone's Lemonade Schnapps"
	desc = "A flavoured grain liqueur with a sweetish, lemon taste."
	icon_state = "schnapps_lem"
	center_of_mass = list("x"=16, "y"=3)

/obj/item/weapon/reagent_containers/food/drinks/bottle/lemonadeschnapps/New()
	. = ..()
	reagents.add_reagent("schnapps_lem", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/cider
	name = "Crisp's Cider"
	desc = "Fermented apples never tasted this good."
	icon_state = "cider"
	center_of_mass = list("x"=16, "y"=12)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/cider/New()
	. = ..()
	reagents.add_reagent("cider", 30)