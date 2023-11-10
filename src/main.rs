#[macro_use]
extern crate rocket;

use rocket_dyn_templates::{Template, context};

#[get("/")]
fn index() -> Template {
    Template::render("index", context! {user: "convos"})
}

#[rocket::main]
async fn main() -> Result<(), rocket::Error> {
    let rocket = rocket::build()
        .attach(Template::fairing())
        .mount("/", routes![index])
        .launch();

    rocket.await?;

    Ok(())
}
