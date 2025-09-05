package main 

import sdl "vendor:sdl2"
import img "vendor:sdl2/image"
import ttf "vendor:sdl2/ttf"
import "core:log"
import "core:os"
import "core:math/rand"
import "core:fmt"

WINDOW_TITLE :: "TRPG"
WINDOW_WIDTH :: 1024
WINDOW_HEIGHT :: 768

FONT_SIZE :: 12

TEXT_VEL :: 3

TICK_SPAN :: 1000 / 60

Position :: struct {
    x: f32,
    y: f32,
}

Movement :: struct {
    x: f32,
    y: f32,
}

Renderable :: struct {
    w: f32,
    h: f32,
    texture_name: string
}

Entity :: struct {
    position: Maybe(Position),
    movement: Maybe(Movement),
    renderable: Maybe(Renderable),
    is_alive: bool,

}

Game :: struct {
    window:   ^sdl.Window,
    renderer: ^sdl.Renderer,
    event:    sdl.Event,
    textures: map[string]^sdl.Texture,
    surfaces: map[string]^sdl.Surface,
    fonts: map[string]^ttf.Font,
    texture_rects: map[string]sdl.Rect,
    added_entities: [dynamic]Entity,
    entities: [dynamic]Entity,
}

generate_entity :: proc() -> Entity {
    entity := Entity {
	is_alive = true,
    }
    
    return entity
}

add_entity :: proc(g: ^Game, entity: Entity) {
    append(&g.added_entities, entity )
}


game_init :: proc (g: ^Game) -> bool  {
    ok := sdl.Init({.VIDEO, .AUDIO})
    assert(ok == 0, sdl.GetErrorString())

    if ok != 0 {
	return false
    }

    // Image Init
    img.Init({.PNG, .JPG})

    // TTF Init
    ttf.Init()

    window := sdl.CreateWindow(
	WINDOW_TITLE, 
	sdl.WINDOWPOS_CENTERED, 
	sdl.WINDOWPOS_CENTERED, 
	WINDOW_WIDTH, WINDOW_HEIGHT, 
	sdl.WINDOW_SHOWN)
    assert(window != nil, sdl.GetErrorString())

    if window == nil {
	return false
    }
    g.window = window

    renderer := sdl.CreateRenderer(
	window, 
	-1, 
	{.ACCELERATED, .TARGETTEXTURE, .PRESENTVSYNC }
    )

    if renderer == nil {
	return false
    }
    g.renderer = renderer
    g.textures = make(map[string]^sdl.Texture)
    g.fonts = make(map[string]^ttf.Font)
    g.texture_rects = make(map[string]sdl.Rect)

    return true

}


movement_system :: proc(g: ^Game, dt: u32) {
    delta := f32(dt) / f32(1000)
    for &entity in g.entities {
	if entity.movement != nil && entity.position != nil {
	    position := entity.position.(Position)
	    movement := entity.movement.(Movement)

	    position.x = position.x + movement.x * delta
	    position.y = position.y + movement.y * delta

	    entity.position = position
	}
    }
}


game_update :: proc(g: ^Game, dt: u32) {

    // system 적용 
    movement_system(g, dt)

    // entity 에서 added_entity 를 넣기 
    append(&g.entities, ..g.added_entities[:])

    clear(&g.added_entities)

    // entity 에서 is_alive == false 삭제 
    idx := 0
    update_loop: for {
	if idx >= len(g.entities) {
	    break update_loop
	}

	if g.entities[idx].is_alive == false {
	    unordered_remove(&g.entities, idx)
	} else {
	    idx = idx + 1
	}
    }
}

game_setup :: proc (g: ^Game) {

    aEntity := generate_entity()

    aEntity.renderable = Renderable {
	texture_name = "font",
	w = 320,
	h =  80,
    }
    aEntity.position = Position {
	x = 0,
	y = 0,
    }

    add_entity(g, aEntity)

    bEntity := generate_entity()
    bEntity.renderable = Renderable {
	texture_name = "text",
	w = f32(g.texture_rects["text"].w),
	h = f32(g.texture_rects["text"].h),
    }
    bEntity.position = Position {
	x = 40,
	y = 120
    }
    bEntity.movement = Movement {
	x = 100,
	y = 100,
    }

    add_entity(g, bEntity)
}


game_render :: proc (g: ^Game) {
    for entity in g.entities {
	if entity.renderable != nil && entity.position != nil {
	    // 위치와 rendering 이 가능 

	    renderable := entity.renderable.(Renderable)
	    position := entity.position.(Position)

	    src_rect := sdl.Rect {
		0, 0,
		i32(renderable.w), i32(renderable.h)
	    }

	    dst_rect := sdl.Rect {
		i32(position.x), i32(position.y), 
		i32(renderable.w), i32(renderable.h)
	    }
	    
	    texture := g.textures[ renderable.texture_name ]

	    if texture != nil {

		sdl.RenderCopy(
		    g.renderer, 
		    texture,
			&src_rect,
			&dst_rect
		)
	    }
	}
    }

}


game_loop :: proc (g: ^Game) {

    tick_start := sdl.GetTicks()
    tick_end := tick_start
    main_loop: for {
	// 이벤트 처리 
	for sdl.PollEvent(&g.event) {
	    #partial switch g.event.type {
		case .QUIT:
		break main_loop

		case .KEYDOWN:
		if g.event.key.keysym.scancode == .ESCAPE do break main_loop
		
	    }
	} 
	// 게임 상태 업데이트 
	

	tick_loop: for {
	    previous_tick_end := tick_end
	    tick_end = sdl.GetTicks()
	    dt := tick_end - previous_tick_end
	    
	    if tick_end - tick_start >= TICK_SPAN do break tick_loop
	    game_update(g, dt)
	}


	// 화면 지우기
	render_background(g)
	sdl.RenderClear(g.renderer)

	// 게임 렌더링  

	/*
	sdl.RenderCopy(
	    g.renderer,
	    g.textures["font"], 
	    &sdl.Rect {0, 0, 320, 80}, 
	    &sdl.Rect {0, 0, 320, 80}
	)
	
	// 폰트 쓰기 
	sdl.RenderCopy(
	    g.renderer,
	    g.textures["text"],
	    nil,
	    &sdl.Rect {0, 80, g.texture_rects["text"].w, g.texture_rects["text"].h}
	)
	*/  

	game_render(g)

	sdl.RenderPresent(g.renderer)
	// fmt.printf("%d - %d = %d\n", tick_end, tick_start, tick_end - tick_start)

	tick_start = sdl.GetTicks()

    }
}


game_cleanup :: proc (g: ^Game) {

    if g != nil {
	if g.renderer != nil do sdl.DestroyRenderer(g.renderer)
	if g.window != nil do sdl.DestroyWindow(g.window)

	// remove textures	
	for texture in g.textures {
	    if g.textures[texture] != nil {
		sdl.DestroyTexture(g.textures[texture])
	    }
	}
	delete(g.textures)

	// remove surfaces
	for surface in g.surfaces {
	    if g.surfaces[surface] != nil {
		sdl.FreeSurface(g.surfaces[surface])
	    }
	}
	delete(g.surfaces)

	for font in g.fonts {
	    if g.fonts[font] != nil {
		ttf.CloseFont(g.fonts[font])
	    }
	}

	delete(g.added_entities)
	delete(g.entities)
    }

    ttf.Quit()
    img.Quit()
    sdl.Quit()
}

load_icon :: proc(g: ^Game) -> bool {
    surface := img.Load("resources/logo.jpg")
    g.surfaces["logo"] = surface

    sdl.SetWindowIcon(g.window, surface)
    return true
}


load_font :: proc(g: ^Game) -> bool {
    font := ttf.OpenFont("fonts/megaman.ttf", FONT_SIZE)
    g.fonts["megaman"] = font

    return true
}

load_media :: proc(g: ^Game) -> bool {
    texture := img.LoadTexture(g.renderer, "resources/dejavu10x10_gs_tc.png")
    g.textures["font"] = texture


    // 폰트로 글 쓰기
    surface := ttf.RenderText_Blended(
	g.fonts["megaman"], 
	"In the name of font", 
	sdl.Color {255, 255, 255, 255}
    )

    g.texture_rects["text"] = sdl.Rect {
	0, 0, surface.w, surface.h
    }
    font_texture := sdl.CreateTextureFromSurface(g.renderer, surface)
    g.textures["text"] = font_texture
    
    sdl.FreeSurface(surface)

    return true
}


render_background :: proc(g: ^Game) {
    if g.renderer != nil {
	red :   u8
	green : u8 
	blue :  u8 
	alpha : u8
	sdl.GetRenderDrawColor(g.renderer, &red, &green, &blue, &alpha)

	red =   (red   + u8(rand.int31_max(10))) % u8(255)
	green = (green + u8(rand.int31_max(10))) % u8(255)
	blue =  (blue  + u8(rand.int31_max(10))) % u8(255)
	sdl.SetRenderDrawColor(
	    g.renderer,
	    red, 
	    green, 
	    blue, 
	    alpha)
    }
}

main :: proc () {
    context.logger = log.create_console_logger()

    log.debug("main")
    exit_status := 0
    g : Game
    
    defer os.exit(exit_status)

    if !game_init(&g) {
	exit_status = 1
	return
    }

    load_font(&g)
    load_media(&g)


    game_setup(&g)

    game_loop(&g)
    game_cleanup(&g)

}
