/* global describe, it, expect */

import Vue from "vue";
import UserRegister from "../../src/components/user-register.vue";

describe("user-register.html.ep", () => {
    it("should render correct contents", () => {
        const vm = new Vue({
            template:   "<div><user-register></user-register></div>",
            components: {
                UserRegister
            }
        }).$mount();
        expect(vm.$el.querySelector(".row p i").textContent).toBe("- Collaboration done right.");
    });
});

// also see example testing a component with mocks at
// https://github.com/vuejs/vueify-example/blob/master/test/unit/a.spec.js#L22-L43
