#[macro_use]
extern crate rocket;

use rocket_dyn_templates::{context, Template};

#[get("/")]
fn index() -> Template {
    Template::render("index", context! {title: "Index", user: "convos"})
}

#[get("/chat/<connection_id>")]
fn chat_connection(connection_id: &str) -> Template {
    Template::render(
        "chat/index",
        context! {
            title: connection_id,
            conversation_id: "",
            connection_id: connection_id,
        },
    )
}

#[get("/chat/<connection_id>/<conversation_id>")]
fn chat_conversation(connection_id: &str, conversation_id: &str) -> Template {
    Template::render(
        "chat/index",
        context! {
            title: conversation_id,
            conversation_id: conversation_id,
            connection_id: connection_id,
        },
    )
}

#[rocket::main]
async fn main() -> Result<(), rocket::Error> {
    let rocket = rocket::build()
        .attach(Template::fairing())
        .mount("/", routes![chat_connection])
        .mount("/", routes![chat_conversation])
        .mount("/", routes![index])
        .launch();

    rocket.await?;

    Ok(())
}
