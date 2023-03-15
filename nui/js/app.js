let currentId = "";

$(document).ready(function() {
    window.addEventListener("message", function(event) {
        let data = event.data
        let action = data.action

        if (action == "OpenMenu") {
            OpenMenu()
        }

        if (action == "SendNoti") {
            console.log(data.data)
            M.toast({html : data.data})
        }

        if (action == "SearchCompelted") {
            PersonalMenu(data.data)
        }

    })

    $(document).keydown(function(key) {
        if (key.keyCode == 27) {
            CloseMenus()
        }
    })

    $(document).on("click", ".imgs", function() {
        $(".inputContent").show()
        $(".personContent").hide()
        $("input").val("")
        $('input').next().removeClass('active');
    })

    $(document).on("click", "#completeSearch", function() {
        const value = $("#dob").val()

        if (value == "") {
            M.toast({html : "Vänligen skriv in ett personnummer."})
        } else {
            $.post(`https://force_evidence/CompleteSearch`, JSON.stringify(value))
        }
    })

    $(document).on("click", "#OpenStash", function() {
        $("input").val("")
        $('input').next().removeClass('active');
        $(".wrapper").hide(250)
        $(".personContent").hide()

        $.post(`https://force_evidence/NuiFocus`, JSON.stringify(false))

        $.post(`https://force_evidence/OpenStash`, JSON.stringify(currentId))
    })
})

function OpenMenu() {
    $(".wrapper").show(250)
    $(".inputContent").show()
    $.post(`https://force_evidence/NuiFocus`, JSON.stringify(true))
}

function PersonalMenu(data) {
    currentId = data.id

    $(`.personalinfo`).html(`
        <p class="playerInfo">FÖRNAMN: ${data.firstname}</p>
        <p class="playerInfo">EFTERNAMN: ${data.lastname}</p>
        <p class="playerInfo">PERSONNUMMER: ${data.id}</p>
    `);

    $(".personContent").show()
    $(".inputContent").hide()
}

function CloseMenus() {
    $("input").val("")
    $('input').next().removeClass('active');
    $(".wrapper").hide(250)
    $(".personContent").hide()
    $.post(`https://force_evidence/NuiFocus`, JSON.stringify(false))
}